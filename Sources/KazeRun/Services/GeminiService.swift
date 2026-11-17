import Foundation

final class GeminiService {
    static let shared = GeminiService()

    private init() {}

    func testConnection(apiKey: String, baseUrl: String, model: String) async -> AIConnectionState {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return .failure(error: "请先填写 Gemini API Key")
        }

        var cleanBaseUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBaseUrl.hasSuffix("/") {
            cleanBaseUrl = String(cleanBaseUrl.dropLast())
        }
        if cleanBaseUrl.isEmpty {
            cleanBaseUrl = "https://generativelanguage.googleapis.com"
        }

        // 1. Try GET /v1beta/models (0-Token official discovery & validation)
        guard let modelsUrl = URL(string: "\(cleanBaseUrl)/v1beta/models") else {
            return .failure(error: "Base URL 格式无效")
        }

        var request = URLRequest(url: modelsUrl)
        request.httpMethod = "GET"
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if #available(macOS 11.3, *) {
            request.assumesHTTP3Capable = false
        }
        request.timeoutInterval = 12.0

        // Attempt 1: Standard system network configuration (inherits system proxy/VPN if present)
        let systemConfig = URLSessionConfiguration.ephemeral
        systemConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
        systemConfig.tlsMaximumSupportedProtocolVersion = .TLSv13
        systemConfig.timeoutIntervalForRequest = 10.0
        systemConfig.timeoutIntervalForResource = 15.0
        let systemSession = URLSession(configuration: systemConfig)

        let result = await executeRequest(session: systemSession, request: request)
        switch result {
        case .success:
            return result
        case .failure(let firstError):
            // Attempt 2: If system proxy caused a TLS handshake abort or host unreachable,
            // fall back to direct socket connection (bypassing HTTP proxy, using native network / TUN).
            let directConfig = URLSessionConfiguration.ephemeral
            directConfig.connectionProxyDictionary = [:] // Bypass HTTP proxy for direct connectivity
            directConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
            directConfig.tlsMaximumSupportedProtocolVersion = .TLSv13
            directConfig.timeoutIntervalForRequest = 10.0
            directConfig.timeoutIntervalForResource = 15.0
            let directSession = URLSession(configuration: directConfig)

            let directResult = await executeRequest(session: directSession, request: request)
            switch directResult {
            case .success:
                return directResult
            case .failure:
                // Both attempts failed, return the most descriptive error
                return .failure(error: firstError)
            case .idle, .testing:
                return directResult
            }
        case .idle, .testing:
            return result
        }
    }

    private func executeRequest(session: URLSession, request: URLRequest) async -> AIConnectionState {
        let start = DispatchTime.now()
        do {
            let (data, response) = try await session.data(for: request)
            let latency = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

            guard let http = response as? HTTPURLResponse else {
                return .failure(error: "非标准 HTTP 响应")
            }

            if http.statusCode == 200 {
                var modelIds: [String] = []
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let list = json["models"] as? [[String: Any]] {
                    for item in list {
                        if let name = item["name"] as? String {
                            let cleanName = name.hasPrefix("models/") ? String(name.dropFirst(7)) : name
                            let methods = item["supportedGenerationMethods"] as? [String] ?? []
                            if methods.contains("generateContent")
                                && !cleanName.contains("embedding")
                                && !cleanName.contains("aqa")
                                && !cleanName.contains("imagen") {
                                modelIds.append(cleanName)
                            }
                        }
                    }
                }
                // Sort with flash models first
                modelIds.sort { a, b in
                    if a.contains("flash") && !b.contains("flash") { return true }
                    if !a.contains("flash") && b.contains("flash") { return false }
                    return a < b
                }
                return .success(latencyMs: latency, models: modelIds)
            } else {
                let errText = parseErrorMessage(data: data) ?? "HTTP \(http.statusCode)"
                return .failure(error: "连接失败 (\(http.statusCode)): \(errText)")
            }
        } catch let nsError as NSError {
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorSecureConnectionFailed:
                    return .failure(error: "安全连接失败 (TLS 握手异常)，请检查当前网络状态或代理服务配置")
                case NSURLErrorTimedOut:
                    return .failure(error: "连接超时，请检查网络连接或尝试更换接入点")
                case NSURLErrorCannotConnectToHost:
                    return .failure(error: "无法连接到服务，请确认网络连接或接入点 (Base URL) 是否有效")
                case NSURLErrorNetworkConnectionLost:
                    return .failure(error: "网络连接中断，请重试")
                default:
                    break
                }
            }
            return .failure(error: "网络连接失败: \(nsError.localizedDescription)")
        }
    }

    private func parseErrorMessage(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.prefix(100).description
        }
        if let errObj = json["error"] as? [String: Any], let msg = errObj["message"] as? String {
            return msg
        }
        if let msg = json["message"] as? String {
            return msg
        }
        return nil
    }
}
