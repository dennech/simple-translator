import Foundation

struct TranslationSnapshot {
    let source: String
    let translation: String
    let provider: Provider
    let model: String
    let sourceLanguage: String
    let targetLanguage: String
    let revision: Int

    func appendedText(for text: String, configuration: TranslationConfiguration, revision: Int) -> String? {
        guard provider == configuration.provider, model == configuration.model,
              sourceLanguage == configuration.source, targetLanguage == configuration.target,
              self.revision == revision, text.hasPrefix(source), text != source else { return nil }
        let suffix = String(text.dropFirst(source.count))
        // A new paragraph can keep the completed prefix. Editing a sentence needs full context.
        guard suffix.hasPrefix("\n") || suffix.hasPrefix("\r") || source.hasSuffix("\n") else { return nil }
        return suffix
    }
}
