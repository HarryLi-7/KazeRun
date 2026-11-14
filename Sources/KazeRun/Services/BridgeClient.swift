import Foundation

actor BridgeClient {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var readTask: Task<Void, Never>?
    private var nextId: Int = 1
    private var waiters: [Int: CheckedContinuation<Data, Error>] = [:]
    private let decoder = JSONDecoder()

    struct ResolvedRuntime {
        let executablePath: String
        let arguments: [String]
        let workingDirectory: URL?
        let modeDescription: String
    }

    nonisolated static func resolveRuntime() -> ResolvedRuntime {
        let fm = FileManager.default

        // 1. Standalone bundled sidecar inside .app/Contents/Resources/sidecar/kaze-bridge (for brand-new Mac!)
        if let resURL = Bundle.main.resourceURL {
            let bundledBin = resURL.appendingPathComponent("sidecar/kaze-bridge")
            if fm.isExecutableFile(atPath: bundledBin.path) {
                return ResolvedRuntime(
                    executablePath: bundledBin.path,
                    arguments: [],
                    workingDirectory: resURL.appendingPathComponent("sidecar"),
                    modeDescription: "Bundled Sidecar (Standalone)"
                )
            }
            let bundledPy = resURL.appendingPathComponent("sidecar/venv/bin/python3")
            let bundledScript = resURL.appendingPathComponent("sidecar/kaze_bridge.py")
            if fm.isExecutableFile(atPath: bundledPy.path) && fm.fileExists(atPath: bundledScript.path) {
                return ResolvedRuntime(
                    executablePath: bundledPy.path,
                    arguments: ["-u", bundledScript.path],
                    workingDirectory: resURL.appendingPathComponent("sidecar"),
                    modeDescription: "Bundled Python Runtime"
                )
            }
        }

        // 2. Project-local venv + bridge/kaze_bridge.py (when building/running from source)
        var candidates: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath)
        ]
        if let envRoot = ProcessInfo.processInfo.environment["KAZERUN_PROJECT_ROOT"], !envRoot.isEmpty {
            candidates.append(URL(fileURLWithPath: envRoot))
        }
        let sourceFileDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(sourceFileDir)

        let bundleURL = Bundle.main.bundleURL
        candidates.append(bundleURL.deletingLastPathComponent())
        candidates.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent())

        for root in candidates {
            let script = root.appendingPathComponent("bridge/kaze_bridge.py")
            guard fm.fileExists(atPath: script.path) else { continue }

            // Custom python binary from environment
            if let customPy = ProcessInfo.processInfo.environment["KAZERUN_PYTHON"],
               fm.isExecutableFile(atPath: customPy) {
                return ResolvedRuntime(
                    executablePath: customPy,
                    arguments: ["-u", script.path],
                    workingDirectory: root,
                    modeDescription: "Custom KAZERUN_PYTHON"
                )
            }

            // Project virtualenv: bridge/.venv or .venv
            let venvCandidates = [
                root.appendingPathComponent("bridge/.venv/bin/python3"),
                root.appendingPathComponent("bridge/.venv/bin/python"),
                root.appendingPathComponent(".venv/bin/python3"),
                root.appendingPathComponent(".venv/bin/python")
            ]
            for venvPy in venvCandidates {
                if fm.isExecutableFile(atPath: venvPy.path) {
                    return ResolvedRuntime(
                        executablePath: venvPy.path,
                        arguments: ["-u", script.path],
                        workingDirectory: root,
                        modeDescription: "Project .venv"
                    )
                }
            }

            // Active virtual environment from shell
            if let activeVenv = ProcessInfo.processInfo.environment["VIRTUAL_ENV"] {
                let venvPy = URL(fileURLWithPath: activeVenv).appendingPathComponent("bin/python3")
                if fm.isExecutableFile(atPath: venvPy.path) {
                    return ResolvedRuntime(
                        executablePath: venvPy.path,
                        arguments: ["-u", script.path],
                        workingDirectory: root,
                        modeDescription: "Active VIRTUAL_ENV"
                    )
                }
            }

            // Optional dev venv override from environment
            if let devEnv = ProcessInfo.processInfo.environment["KAZERUN_DEV_VENV"],
               fm.isExecutableFile(atPath: devEnv) {
                return ResolvedRuntime(
                    executablePath: devEnv,
                    arguments: ["-u", script.path],
                    workingDirectory: root,
                    modeDescription: "Dev KAZERUN_DEV_VENV"
                )
            }

            // Standard Homebrew (Apple Silicon & Intel)
            for brewPath in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
                if fm.isExecutableFile(atPath: brewPath) {
                    return ResolvedRuntime(
                        executablePath: brewPath,
                        arguments: ["-u", script.path],
                        workingDirectory: root,
                        modeDescription: "Homebrew Python3"
                    )
                }
            }
        }

        return ResolvedRuntime(
            executablePath: "/usr/bin/python3",
            arguments: ["-u", "bridge/kaze_bridge.py"],
            workingDirectory: nil,
            modeDescription: "System Python3 (Fallback)"
        )
    }

    func runtimeDescription() -> String {
        Self.resolveRuntime().modeDescription
    }

    private func ensureStarted() throws {
        if let proc = process, proc.isRunning {
            return
        }
        cleanup()

        let runtime = Self.resolveRuntime()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: runtime.executablePath)
        proc.arguments = runtime.arguments
        if let wd = runtime.workingDirectory {
            proc.currentDirectoryURL = wd
        }

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        proc.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        proc.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination() }
        }

        try proc.run()
        self.process = proc
        self.stdinHandle = stdinPipe.fileHandleForWriting

        let stdoutHandle = stdoutPipe.fileHandleForReading
        self.readTask = Task.detached { [weak self] in
            var buffer = Data()
            while true {
                let chunk = stdoutHandle.availableData
                if chunk.isEmpty {
                    break
                }
                buffer.append(chunk)
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: 0..<newlineIndex)
                    buffer.removeSubrange(0...newlineIndex)
                    if !lineData.isEmpty {
                        await self?.handleLine(lineData)
                    }
                }
            }
            await self?.handleTermination()
        }

        // Drain stderr so pipe never blocks
        let errHandle = stderrPipe.fileHandleForReading
        Task.detached {
            while true {
                let chunk = errHandle.availableData
                if chunk.isEmpty { break }
            }
        }
    }

    private func handleLine(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["id"] as? Int else {
            return
        }
        if let cont = waiters.removeValue(forKey: id) {
            cont.resume(returning: data)
        }
    }

    private func handleTermination() {
        let err = BridgeErrorInfo(code: "bridge_terminated", message: "后台数据桥接进程已退出，请重试。")
        let pending = waiters
        waiters.removeAll()
        for (_, cont) in pending {
            cont.resume(throwing: err)
        }
        process = nil
        stdinHandle = nil
    }

    private func cleanup() {
        readTask?.cancel()
        readTask = nil
        if let p = process, p.isRunning {
            p.terminate()
        }
        process = nil
        stdinHandle = nil
    }

    func call<T: Decodable>(method: String, params: [String: Any] = [:], as type: T.Type) async throws -> T {
        let rawData = try await callRaw(method: method, params: params)
        do {
            return try decoder.decode(T.self, from: rawData)
        } catch {
            let preview = String(data: rawData.prefix(400), encoding: .utf8) ?? ""
            throw BridgeErrorInfo(
                code: "decode_error",
                message: "解析 \(method) 返回失败: \(error.localizedDescription)\n\(preview)"
            )
        }
    }

    func callRaw(method: String, params: [String: Any] = [:]) async throws -> Data {
        try ensureStarted()
        let reqId = nextId
        nextId += 1

        let payload: [String: Any] = [
            "id": reqId,
            "method": method,
            "params": params
        ]
        var lineData = try JSONSerialization.data(withJSONObject: payload, options: [])
        lineData.append(0x0A)

        guard let handle = stdinHandle else {
            throw BridgeErrorInfo(code: "bridge_unavailable", message: "桥接通道未就绪")
        }

        let responseData: Data = try await withCheckedThrowingContinuation { cont in
            waiters[reqId] = cont
            do {
                try handle.write(contentsOf: lineData)
            } catch {
                waiters.removeValue(forKey: reqId)
                cont.resume(throwing: BridgeErrorInfo(code: "write_failed", message: error.localizedDescription))
            }
        }

        guard let root = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw BridgeErrorInfo(code: "invalid_response", message: "无效 JSON 响应")
        }

        let ok = root["ok"] as? Bool ?? false
        if !ok {
            let errObj = root["error"] as? [String: Any]
            let code = errObj?["error_code"] as? String ?? "unknown_error"
            let msg = errObj?["message"] as? String ?? "未知错误"
            throw BridgeErrorInfo(code: code, message: msg)
        }

        let resultObj = root["result"] ?? [:]
        return try JSONSerialization.data(withJSONObject: resultObj, options: [])
    }

    func callDictionary(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let data = try await callRaw(method: method, params: params)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
