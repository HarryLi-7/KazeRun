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
        // Inject ?key= parameter to ensure maximum compatibility across proxies and Google endpoints
        var components = URLComponents(string: "\(cleanBaseUrl)/v1beta/models")
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: cleanKey))
        components?.queryItems = queryItems

        guard let modelsUrl = components?.url ?? URL(string: "\(cleanBaseUrl)/v1beta/models") else {
            return .failure(error: "Base URL 格式无效")
        }

        var request = URLRequest(url: modelsUrl)
        request.httpMethod = "GET"
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12.0

        // Perform request with 1-time retry for transient TLS/proxy handshake resets
        return await executeWithRetry(request: request, attempt: 1)
    }

    private func executeWithRetry(request: URLRequest, attempt: Int) async -> AIConnectionState {
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
            // Transient TLS or timeout glitch: retry once after 500ms
            if attempt == 1 && (nsError.code == NSURLErrorSecureConnectionFailed || nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost) {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return await executeWithRetry(request: request, attempt: 2)
            }

            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorSecureConnectionFailed:
                    return .failure(error: "代理节点 TLS 握手中断，请检查小火箭节点出海连通性后重试")
                case NSURLErrorTimedOut:
                    return .failure(error: "连接超时，建议在小火箭切换延迟更低的出海节点重试")
                case NSURLErrorCannotConnectToHost:
                    return .failure(error: "无法连接到服务器，请检查代理网络服务")
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
