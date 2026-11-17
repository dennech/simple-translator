import Foundation

enum ProviderRequests {
    static func cloudflareAccount(_ options: ConnectionOptions) throws -> String {
        let account = options.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard account.range(of: "^[a-fA-F0-9]{32}$", options: .regularExpression) != nil else { throw TranslationError.missingParameters }
        return account
    }
    static func chatURL(_ provider: Provider, options: ConnectionOptions) throws -> URL {
        if provider == .cloudflare {
            return provider.baseURL.appendingPathComponent("accounts/\(try cloudflareAccount(options))/ai/v1/chat/completions")
        }
        return provider.baseURL.appendingPathComponent("chat/completions")
    }
    static func validateModel(_ c: TranslationConfiguration) throws {
        guard !c.model.isEmpty else { throw TranslationError.missingModel }
        if c.provider == .huggingFace {
            guard let separator = c.model.lastIndex(of: ":") else { throw TranslationError.missingParameters }
            let route = String(c.model[c.model.index(after: separator)...])
            guard !["auto", "fastest", "cheapest", "preferred"].contains(route),
                  route.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { throw TranslationError.missingParameters }
        }
    }
    static func explicitSource(_ text: String, configuration c: TranslationConfiguration) throws -> String {
        if c.source != Languages.auto { return c.source }
        guard let language = Languages.detect(text) else { throw TranslationError.unsupportedLanguage }
        return language
    }
    static func specialized(_ text: String, configuration c: TranslationConfiguration) throws -> URLRequest {
        var request: URLRequest
        var body: Any = [:]
        switch c.provider {
        case .azure:
            var url = URLComponents(url: c.provider.baseURL.appendingPathComponent("translate"), resolvingAgainstBaseURL: false)!
            url.queryItems = [URLQueryItem(name: "api-version", value: "3.0"), URLQueryItem(name: "to", value: c.target)]
            if c.source != Languages.auto { url.queryItems?.append(URLQueryItem(name: "from", value: c.source)) }
            request = URLRequest(url: url.url!)
            request.setValue(c.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
            if !c.options.region.isEmpty {
                guard c.options.region.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else { throw TranslationError.missingParameters }
                request.setValue(c.options.region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
            }
            body = [["Text": text]]
        case .googleCloud:
            request = URLRequest(url: c.provider.baseURL.appendingPathComponent("language/translate/v2"))
            request.setValue(c.key, forHTTPHeaderField: "X-Goog-Api-Key")
            var fields: [String: Any] = ["q": [text], "target": c.target, "format": "text", "model": "nmt"]
            if c.source != Languages.auto { fields["source"] = c.source }
            body = fields
        case .myMemory:
            let source = try explicitSource(text, configuration: c)
            var url = URLComponents(url: c.provider.baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: false)!
            url.queryItems = [URLQueryItem(name: "q", value: text), URLQueryItem(name: "langpair", value: "\(source)|\(c.target)")]
            if !c.key.isEmpty {
                guard c.key.contains("@"), !c.key.contains(where: { $0.isWhitespace }) else { throw TranslationError.missingParameters }
                url.queryItems?.append(URLQueryItem(name: "de", value: c.key))
            }
            return URLRequest(url: url.url!)
        case .yandex:
            request = URLRequest(url: c.provider.baseURL.appendingPathComponent("translate/v2/translate"))
            request.setValue("Api-Key \(c.key)", forHTTPHeaderField: "Authorization")
            var fields: [String: Any] = ["texts": [text], "targetLanguageCode": c.target, "format": "PLAIN_TEXT"]
            if c.source != Languages.auto { fields["sourceLanguageCode"] = c.source }
            body = fields
        case .amazon:
            return try AWSSigner.request(text: text, source: explicitSource(text, configuration: c), target: c.target,
                                         region: c.options.region, credentials: AWSCredentials.decode(c.key))
        default: throw TranslationError.invalidResponse
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    static func translatedText(_ data: Data, provider: Provider) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        let object = json as? [String: Any] ?? [:]
        let result: String?
        switch provider {
        case .azure: result = (((json as? [[String: Any]])?.first?["translations"] as? [[String: Any]])?.first?["text"] as? String)
        case .googleCloud:
            let value = ((object["data"] as? [String: Any])?["translations"] as? [[String: Any]])?.first?["translatedText"] as? String
            result = value.map(decodeEntities)
        case .myMemory:
            let status = (object["responseStatus"] as? Int) ?? Int(object["responseStatus"] as? String ?? "")
            guard status == 200, object["quotaFinished"] as? Bool != true else { throw TranslationError.server(status == 200 ? 429 : status ?? 502) }
            result = (object["responseData"] as? [String: Any])?["translatedText"] as? String
        case .yandex: result = (object["translations"] as? [[String: Any]])?.first?["text"] as? String
        case .amazon: result = object["TranslatedText"] as? String
        default: throw TranslationError.invalidResponse
        }
        guard let result, !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TranslationError.emptyResponse }
        return result
    }
    private static func decodeEntities(_ text: String) -> String {
        let regex = try! NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|amp|quot|apos|lt|gt);")
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range(at: 1), in: text), let full = Range(match.range, in: result) else { continue }
            let entity = String(text[range])
            var value = ["amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">"][entity]
            if entity.hasPrefix("#") {
                let hex = entity.hasPrefix("#x")
                if let number = UInt32(entity.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10), let scalar = UnicodeScalar(number) { value = String(scalar) }
            }
            if let value { result.replaceSubrange(full, with: value) }
        }
        return result
    }
}
