import Foundation

enum ConnectionCheck {
    /// Explicit developer check; only a synthetic example is sent. Never prints credentials.
    static func run(provider: Provider) async -> Int32 {
        do {
            guard let key = try Keychain.read(provider), !key.isEmpty else { throw TranslationError.missingKey }
            let client = TranslationClient.shared
            let models = try await client.models(provider: provider, key: key)
            print("\(provider.title): model list OK (\(models.count))")
            let started = Date()
            let configuration = TranslationConfiguration(provider: provider, model: provider.defaultModel, key: key, source: "en", target: "ru")
            let result = try await client.translate("Please send the final mix by Friday.\n\nKeep the music under the voice.", configuration: configuration) { _ in }
            guard result.contains("\n\n"), result.range(of: "[А-Яа-я]", options: .regularExpression) != nil else { throw TranslationError.invalidResponse }
            print("\(provider.title): translation OK, \(String(format: "%.2f", Date().timeIntervalSince(started))) s")
            print(result)
            return 0
        } catch {
            print("\(provider.title): \(TranslationError.message(for: error))")
            return 1
        }
    }
}
