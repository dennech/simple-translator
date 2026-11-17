import SwiftUI
import Observation

@MainActor @Observable final class TranslatorStore {
    var sourceText = ""
    private(set) var translatedText = ""
    var sourceLanguage = Languages.auto
    var targetLanguage = Languages.auto
    private(set) var detectedLanguage: String?
    private(set) var isTranslating = false
    private(set) var isComplete = false
    private(set) var error: String?
    var resolvedSource: String? { sourceLanguage == Languages.auto ? detectedLanguage : sourceLanguage }
    var resolvedTarget: String { Languages.target(selected: targetLanguage, source: resolvedSource) }
    @ObservationIgnored private var task: Task<Void, Never>?
    private(set) var requestID = UUID()
    private var isDemonstration = false
    @ObservationIgnored private var cache: [CacheKey: String] = [:]
    @ObservationIgnored private var cacheOrder: [CacheKey] = []
    @ObservationIgnored private let client: any Translating
    @ObservationIgnored private let configuration: @MainActor (Preferences, String, String) throws -> TranslationConfiguration
    @ObservationIgnored private var lastCompleted: TranslationSnapshot?

    struct CacheKey: Hashable {
        let text: String
        let provider: Provider
        let model: String
        let source: String
        let target: String
        let revision: Int
    }

    init(client: any Translating = TranslationClient.shared,
         configuration: @escaping @MainActor (Preferences, String, String) throws -> TranslationConfiguration = {
             try $0.configuration(source: $1, target: $2)
         }) {
        self.client = client
        self.configuration = configuration
    }

    /// An entirely offline preview: neither the client nor configuration accesses credentials.
    static func demonstration() -> TranslatorStore {
        let store = TranslatorStore(client: DemonstrationTranslator()) { _, source, target in
            TranslationConfiguration(provider: .deepL, model: "demo", key: "", source: source, target: target)
        }
        store.isDemonstration = true
        store.sourceLanguage = "en"
        store.targetLanguage = "ru"
        store.detectedLanguage = "en"
        store.sourceText = "Small details make a big difference.\n\nA quiet place to put your thoughts into words — in any language.\n\nWrite. Translate. Keep going."
        store.translatedText = DemonstrationTranslator.translation
        store.isComplete = true
        return store
    }

    func schedule(preferences: Preferences, immediately: Bool = false) {
        task?.cancel()
        requestID = UUID()
        let id = requestID
        isComplete = false
        error = nil
        let text = sourceText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translatedText = ""
            lastCompleted = nil
            isTranslating = false
            detectedLanguage = nil
            return
        }
        isTranslating = true
        task = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(for: .milliseconds(450)) }
                try Task.checkCancellation()
                guard let self, self.requestID == id else { return }
                self.detectedLanguage = Languages.detect(text)
                let target = self.resolvedTarget
                if self.resolvedSource == target {
                    self.lastCompleted = nil
                    self.translatedText = text
                    self.isTranslating = false
                    self.isComplete = true
                    return
                }
                let config = try self.configuration(preferences, self.sourceLanguage, target)
                let revision = preferences.revision
                let cacheKey = CacheKey(text: text, provider: config.provider, model: config.model,
                                        source: config.source, target: target, revision: preferences.revision)
                if let cached = self.cache[cacheKey] {
                    self.translatedText = cached
                } else {
                    let suffix = self.lastCompleted?.appendedText(for: text, configuration: config, revision: revision)
                    let prefix = suffix == nil ? "" : self.lastCompleted?.translation ?? ""
                    let showStream = suffix != nil || self.translatedText.isEmpty
                    let result = try await self.client.translate(suffix ?? text, configuration: config) { [weak self] partial in
                        if showStream { await self?.receive(prefix + partial, id: id) }
                    }
                    try Task.checkCancellation()
                    guard self.requestID == id else { return }
                    self.translatedText = prefix + result
                    if text.count + self.translatedText.count <= 100_000 {
                        self.cache[cacheKey] = self.translatedText
                        self.cacheOrder.append(cacheKey)
                        while self.cacheOrder.count > 8 { self.cache.removeValue(forKey: self.cacheOrder.removeFirst()) }
                    }
                }
                self.lastCompleted = TranslationSnapshot(source: text, translation: self.translatedText,
                    provider: config.provider, model: config.model, sourceLanguage: config.source,
                    targetLanguage: config.target, revision: revision)
                self.isTranslating = false
                self.isComplete = true
            } catch is CancellationError { /* A newer request owns the UI. */ }
            catch {
                guard let self, self.requestID == id else { return }
                self.isTranslating = false
                self.error = TranslationError.message(for: error)
            }
        }
    }

    private func receive(_ partial: String, id: UUID) {
        guard requestID == id else { return }
        translatedText = partial
    }

    func alternatives(for word: TranslationWord, id: UUID, preferences: Preferences) async throws -> [WordAlternative] {
        guard isComplete, id == requestID else { throw CancellationError() }
        if isDemonstration {
            if word.word.lowercased() == "место" {
                return ["Тихий уголок", "Уютное пространство"].compactMap {
                    word.alternative(left: "Спокойное ", replacement: $0)
                }
            }
            let examples = ["детали": ["подробности", "нюансы", "мелочи"], "маленькие": ["Небольшие", "Крошечные"],
                            "спокойное": ["Тихое", "Уютное"]]
            return (examples[word.word.lowercased()] ?? []).compactMap { word.alternative(replacement: $0) }
        }
        if let provider = preferences.wordProvider ?? (preferences.provider.isSpecialized ? nil : preferences.provider) {
            let config = try preferences.configuration(for: provider, source: resolvedTarget, target: resolvedTarget)
            return try await TranslationClient.shared.alternatives(for: word, configuration: config)
        }
        return try await LocalWordSuggestions.alternatives(for: word, language: resolvedTarget)
    }

    func replace(_ alternative: WordAlternative, id: UUID) {
        guard isComplete, requestID == id, let range = Range(alternative.range, in: translatedText),
              translatedText[range] == alternative.original else { return }
        translatedText.replaceSubrange(range, with: alternative.replacement)
        requestID = UUID()
        if var snapshot = lastCompleted {
            snapshot.translation = translatedText
            lastCompleted = snapshot
            let key = CacheKey(text: snapshot.source, provider: snapshot.provider, model: snapshot.model,
                               source: snapshot.sourceLanguage, target: snapshot.targetLanguage, revision: snapshot.revision)
            if cache[key] != nil { cache[key] = translatedText }
        }
    }

    func swap() {
        let oldSource = resolvedSource ?? "en"
        let oldTarget = resolvedTarget
        let oldTranslation = translatedText
        task?.cancel()
        requestID = UUID()
        sourceLanguage = oldTarget
        targetLanguage = oldSource
        if isComplete { sourceText = oldTranslation }
    }

    func clear() {
        task?.cancel()
        requestID = UUID()
        sourceText = ""
        translatedText = ""
        detectedLanguage = nil
        error = nil
        isTranslating = false
        isComplete = false
        cache.removeAll()
        cacheOrder.removeAll()
        lastCompleted = nil
    }
}

private struct DemonstrationTranslator: Translating {
    static let translation = "Маленькие детали многое меняют.\n\nСпокойное место, где мысли обретают слова — на любом языке.\n\nПишите. Переводите. Продолжайте."
    func translate(_ text: String, configuration: TranslationConfiguration,
                   onUpdate: @escaping @Sendable (String) async -> Void) async throws -> String {
        try await Task.sleep(for: .seconds(3))
        try Task.checkCancellation()
        return Self.translation
    }
}
