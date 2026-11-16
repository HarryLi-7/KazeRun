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
