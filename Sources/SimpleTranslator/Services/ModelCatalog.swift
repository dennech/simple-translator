import Foundation

enum ModelCatalog {
    static func localModels(_ provider: Provider) -> [ModelOption]? {
        if provider == .deepL {
            return [ModelOption(id: "prefer_quality_optimized", name: "Лучшее доступное качество", billing: provider.billingLabel(model: "")),
                    ModelOption(id: "latency_optimized", name: "Быстрый перевод", billing: provider.billingLabel(model: "")),
                    ModelOption(id: "quality_optimized", name: "Максимальное качество", billing: provider.billingLabel(model: ""))]
        }
        if provider.isSpecialized { return [ModelOption(id: "standard", name: "Стандартный перевод", billing: provider.billingLabel(model: ""))] }
        return nil
    }

    static func request(provider: Provider, key: String, options: ConnectionOptions) throws -> URLRequest {
        var url = provider.baseURL.appendingPathComponent("models")
        switch provider {
        case .gemini: url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000")!
        case .fireworks: url = URL(string: "https://api.fireworks.ai/v1/accounts/fireworks/models?pageSize=200")!
        case .cloudflare:
            url = provider.baseURL.appendingPathComponent("accounts/\(try ProviderRequests.cloudflareAccount(options))/ai/models/search")
        default: break
        }
        var request = URLRequest(url: url)
        if provider.modelListRequiresKey {
            guard !key.isEmpty else { throw TranslationError.missingKey }
            if provider == .gemini { request.setValue(key, forHTTPHeaderField: "x-goog-api-key") }
            else { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        }
        return request
    }

    static func parse(_ data: Data, provider: Provider) throws -> [ModelOption] {
        let json = try JSONSerialization.jsonObject(with: data)
        let object = json as? [String: Any] ?? [:]
        let items: [[String: Any]]
        switch provider {
        case .gemini, .fireworks: items = object["models"] as? [[String: Any]] ?? []
        case .cloudflare: items = object["result"] as? [[String: Any]] ?? []
        case .together: items = json as? [[String: Any]] ?? []
        default: items = object["data"] as? [[String: Any]] ?? []
        }
        var result: [ModelOption] = []
        for item in items {
            if item["active"] as? Bool == false { continue }
            if provider == .huggingFace {
                guard let id = item["id"] as? String,
                      let architecture = item["architecture"] as? [String: Any],
                      (architecture["output_modalities"] as? [String])?.contains("text") == true else { continue }
                for route in item["providers"] as? [[String: Any]] ?? [] {
                    guard let name = route["provider"] as? String, route["status"] as? String == "live",
                          !["auto", "fastest", "cheapest", "preferred"].contains(name) else { continue }
                    let prices = route["pricing"] as? [String: Any] ?? [:]
                    result.append(ModelOption(id: "\(id):\(name)", name: "\(id) · \(name)",
                        inputPrice: number(prices["input"]).map { $0 / 1_000_000 },
                        outputPrice: number(prices["output"]).map { $0 / 1_000_000 },
                        billing: provider.billingLabel(model: id)))
                }
                continue
            }
            let id: String
            if provider == .gemini {
                guard let name = item["name"] as? String,
                      (item["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true,
                      !["image", "tts", "robotics", "computer-use"].contains(where: { name.contains($0) }) else { continue }
                id = name.replacingOccurrences(of: "models/", with: "")
            } else if provider == .fireworks {
                guard item["supportsServerless"] as? Bool == true, let name = item["name"] as? String,
                      !["embedding", "whisper", "image", "flux"].contains(where: { name.lowercased().contains($0) }) else { continue }
                id = name
            } else if provider == .cloudflare {
                guard let name = item["name"] as? String,
                      ((item["task"] as? [String: Any])?["name"] as? String)?.lowercased() == "text generation" else { continue }
                id = name
            } else {
                guard let identifier = item["id"] as? String else { continue }
                id = identifier
            }
            if provider == .openAI && !TranslationClient.isOpenAIChatModel(id) { continue }
            if provider == .openRouter {
                guard !id.contains(":batch"), let architecture = item["architecture"] as? [String: Any],
                      architecture["output_modalities"] as? [String] == ["text"] else { continue }
                let prices = item["pricing"] as? [String: Any] ?? [:]
                result.append(ModelOption(id: id, name: item["name"] as? String ?? id,
                    inputPrice: number(prices["prompt"]), outputPrice: number(prices["completion"]),
                    requestPrice: number(prices["request"]) ?? 0))
            } else {
                if ![.openAI, .gemini].contains(provider), ["embedding", "rerank", "whisper", "stable-diffusion", "flux", "-tts", "ocr"].contains(where: { id.lowercased().contains($0) }) { continue }
                if let type = item["type"] as? String, ["embedding", "image", "audio", "rerank"].contains(type) { continue }
                if let capabilities = item["capabilities"] as? [String: Any], capabilities["completion_chat"] as? Bool == false { continue }
                let prices = provider == .sambaNova ? item["pricing"] as? [String: Any] ?? [:] : [:]
                result.append(ModelOption(id: id, name: item["displayName"] as? String ?? id,
                    inputPrice: number(prices["prompt"]), outputPrice: number(prices["completion"]), billing: provider.billingLabel(model: id)))
            }
        }
        return Array(Set(result)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}
