import Foundation

enum AIConnectionState: Equatable {
    case idle
    case testing
    case success(latencyMs: Int, models: [String])
    case failure(error: String)
}

typealias DeepSeekConnectionState = AIConnectionState

final class DeepSeekService {
    static let shared = DeepSeekService()

    private init() {}

    func testConnection(apiKey: String, baseUrl: String, model: String) async -> DeepSeekConnectionState {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            return .failure(error: "请先填写 API Key")
        }

        var cleanBaseUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBaseUrl.hasSuffix("/") {
            cleanBaseUrl = String(cleanBaseUrl.dropLast())
        }
        if cleanBaseUrl.isEmpty {
            cleanBaseUrl = "https://api.deepseek.com"
        }

        // 1. Try GET /models (0-Token lightweight check)
        guard let modelsUrl = URL(string: "\(cleanBaseUrl)/models") else {
            return .failure(error: "Base URL 格式无效")
        }

        var request = URLRequest(url: modelsUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        let start = DispatchTime.now()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

            guard let http = response as? HTTPURLResponse else {
                return .failure(error: "非标准 HTTP 响应")
            }

            if http.statusCode == 200 {
                var modelIds: [String] = []
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let list = json["data"] as? [[String: Any]] {
                    modelIds = list.compactMap { $0["id"] as? String }
                }
                return .success(latencyMs: latency, models: modelIds)
            } else if http.statusCode == 404 || http.statusCode == 405 {
                // Relay / proxy fallback: Test with 1-token /chat/completions
                return await testChatCompletions(cleanKey: cleanKey, cleanBaseUrl: cleanBaseUrl, model: model)
            } else {
                let errText = parseErrorMessage(data: data) ?? "HTTP \(http.statusCode)"
                return .failure(error: "连接失败 (\(http.statusCode)): \(errText)")
            }
        } catch {
            return .failure(error: "网络连接失败: \(error.localizedDescription)")
        }
    }

    private func testChatCompletions(cleanKey: String, cleanBaseUrl: String, model: String) async -> DeepSeekConnectionState {
        guard let chatUrl = URL(string: "\(cleanBaseUrl)/chat/completions") else {
            return .failure(error: "Chat API URL 无效")
        }

        var request = URLRequest(url: chatUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let payload: [String: Any] = [
            "model": model.isEmpty ? "deepseek-chat" : model,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let start = DispatchTime.now()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

            guard let http = response as? HTTPURLResponse else {
                return .failure(error: "非标准 HTTP 响应")
            }

            if http.statusCode == 200 {
                return .success(latencyMs: latency, models: [model])
            } else {
                let errText = parseErrorMessage(data: data) ?? "HTTP \(http.statusCode)"
                return .failure(error: "调用失败 (\(http.statusCode)): \(errText)")
            }
        } catch {
            return .failure(error: "网络连接失败: \(error.localizedDescription)")
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
