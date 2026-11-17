import SwiftUI
import Observation

@MainActor @Observable final class Preferences {
    var provider: Provider { didSet { defaults.set(provider.rawValue, forKey: "provider"); revision += 1 } }
    var revision = 0
    private let defaults: UserDefaults
    private var models: [String: String]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .openAI
        models = defaults.dictionary(forKey: "models") as? [String: String] ?? [:]
    }
    var model: String {
        get { models[provider.rawValue] ?? provider.defaultModel }
        set {
            models[provider.rawValue] = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(models, forKey: "models")
            revision += 1
        }
    }
    func configuration(source: String, target: String) throws -> TranslationConfiguration {
        let key = try Keychain.read(provider) ?? ""
        guard !key.isEmpty else { throw TranslationError.missingKey }
        guard !model.isEmpty else { throw TranslationError.invalidResponse }
        return TranslationConfiguration(provider: provider, model: model, key: key, source: source, target: target)
    }
}
