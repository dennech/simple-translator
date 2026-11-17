import SwiftUI
import Observation

@MainActor @Observable final class Preferences {
    var provider: Provider { didSet { defaults.set(provider.rawValue, forKey: "provider"); revision += 1 } }
    var revision = 0
    private let defaults: UserDefaults
    private var models: [String: String]
    private var connections: [String: ConnectionOptions]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .openAI
        models = defaults.dictionary(forKey: "models") as? [String: String] ?? [:]
        connections = defaults.data(forKey: "connections").flatMap { try? JSONDecoder().decode([String: ConnectionOptions].self, from: $0) } ?? [:]
    }
    var connectionOptions: ConnectionOptions {
        get { connections[provider.rawValue] ?? ConnectionOptions() }
        set {
            connections[provider.rawValue] = newValue
            if let data = try? JSONEncoder().encode(connections) { defaults.set(data, forKey: "connections") }
            revision += 1
        }
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
        guard !model.isEmpty else { throw TranslationError.missingModel }
        let key = try Keychain.read(provider) ?? ""
        guard !provider.requiresKey || !key.isEmpty else { throw TranslationError.missingKey }
        return TranslationConfiguration(provider: provider, model: model, key: key, source: source, target: target, options: connectionOptions)
    }
}
