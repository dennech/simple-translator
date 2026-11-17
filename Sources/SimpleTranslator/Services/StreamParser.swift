import Foundation

struct StreamParser {
    private(set) var text = ""
    private(set) var finished = false
    @discardableResult mutating func consume(_ line: String) throws -> Bool {
        guard line.hasPrefix("data:") else { return false }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return false }
        guard !payload.isEmpty else { return false }
        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationError.invalidResponse
        }
        if let error = object["error"] as? [String: Any] {
            throw TranslationError.server(error["code"] as? Int ?? 502)
        }
        guard let choice = (object["choices"] as? [[String: Any]])?.first else { return false }
        if let delta = choice["delta"] as? [String: Any] {
            text += Self.contentText(delta["content"])
            if let refusal = delta["refusal"] as? String, !refusal.isEmpty { throw TranslationError.filtered }
        }
        if let reason = choice["finish_reason"] as? String {
            switch reason {
            case "stop": finished = true
            case "length": throw TranslationError.truncated
            case "content_filter", "blacklist": throw TranslationError.filtered
            default: throw TranslationError.invalidResponse
            }
        }
        return true
    }
    static func contentText(_ content: Any?) -> String {
        if let content = content as? String { return content }
        return (content as? [[String: Any]] ?? []).compactMap { part -> String? in
            guard part["type"] as? String == "text" else { return nil }
            return part["text"] as? String
        }.joined()
    }
    func validate() throws {
        guard finished else { throw TranslationError.interrupted }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TranslationError.emptyResponse }
    }
}
