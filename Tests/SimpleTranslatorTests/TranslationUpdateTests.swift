import Testing
import AppKit
import Foundation
@testable import SimpleTranslator

private actor ControlledTranslator: Translating {
    struct Pending {
        let text: String
        let update: @Sendable (String) async -> Void
        let completion: CheckedContinuation<String, Error>
    }
    var requests: [Pending] = []
    var count: Int { requests.count }
    func translate(_ text: String, configuration: TranslationConfiguration,
                   onUpdate: @escaping @Sendable (String) async -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(Pending(text: text, update: onUpdate, completion: continuation))
        }
    }
    func emit(_ text: String, request: Int) async { await requests[request].update(text) }
    func finish(_ text: String, request: Int) { requests[request].completion.resume(returning: text) }
    func fail(request: Int) { requests[request].completion.resume(throwing: TranslationError.server(429)) }
    func input(_ index: Int) -> String { requests[index].text }
}

@MainActor private func waitUntil(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for a controlled translation")
}

@MainActor private func setup(_ client: ControlledTranslator) -> (TranslatorStore, Preferences) {
    let preferences = Preferences(defaults: UserDefaults(suiteName: "TranslatorTests-\(UUID())")!)
    let store = TranslatorStore(client: client) { _, source, target in
        TranslationConfiguration(provider: .openAI, model: "test", key: "synthetic-test-key", source: source, target: target)
    }
    store.sourceLanguage = "en"
    store.targetLanguage = "ru"
    return (store, preferences)
}

@MainActor @Test func appendingParagraphKeepsCompletedTranslationAndStreamsOnlyNewText() async throws {
    let client = ControlledTranslator()
    let (store, preferences) = setup(client)
    store.sourceText = "Hello."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 1 }
    await client.finish("Привет.", request: 0)
    try await waitUntil { store.isComplete }

    store.sourceText += "\n\nGoodbye."
    store.schedule(preferences: preferences, immediately: true)
    #expect(store.translatedText == "Привет.")
    #expect(!store.isComplete)
    try await waitUntil { await client.count == 2 }
    #expect(await client.input(1) == "\n\nGoodbye.")
    await client.emit("\n\nДо", request: 1)
    #expect(store.translatedText == "Привет.\n\nДо")
    await client.finish("\n\nДо свидания.", request: 1)
    try await waitUntil { store.isComplete }
    #expect(store.translatedText == "Привет.\n\nДо свидания.")
    store.sourceText = ""
    store.schedule(preferences: preferences)
    #expect(store.translatedText.isEmpty)
}

@MainActor @Test func editingSentenceKeepsOldOutputUntilNewTranslationIsComplete() async throws {
    let client = ControlledTranslator()
    let (store, preferences) = setup(client)
    store.sourceText = "Hello."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 1 }
    await client.finish("Привет.", request: 0)
    try await waitUntil { store.isComplete }

    store.sourceText = "Hello again."
    store.schedule(preferences: preferences, immediately: true)
    #expect(store.translatedText == "Привет.")
    try await waitUntil { await client.count == 2 }
    #expect(await client.input(1) == "Hello again.")
    await client.emit("И", request: 1)
    #expect(store.translatedText == "Привет.")
    await client.finish("И снова здравствуйте.", request: 1)
    try await waitUntil { store.isComplete }
    #expect(store.translatedText == "И снова здравствуйте.")

    store.sourceText = "Hello again, my friend."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 3 }
    await client.fail(request: 2)
    try await waitUntil { !store.isTranslating }
    #expect(store.translatedText == "И снова здравствуйте.")
    #expect(store.error != nil)
    #expect(!store.isComplete)
}

@MainActor @Test func staleResponseCannotReplaceNewerText() async throws {
    let client = ControlledTranslator()
    let (store, preferences) = setup(client)
    store.sourceText = "First."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 1 }
    store.sourceText = "Second."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 2 }
    await client.finish("Второй.", request: 1)
    try await waitUntil { store.isComplete }
    await client.emit("Первый.", request: 0)
    await client.finish("Первый.", request: 0)
    try await Task.sleep(for: .milliseconds(20))
    #expect(store.translatedText == "Второй.")
    #expect(store.isComplete)
}

@MainActor @Test func wordReplacementSurvivesAppendingAndCacheButStaleChoiceCannotApply() async throws {
    let client = ControlledTranslator()
    let (store, preferences) = setup(client)
    store.sourceText = "Details, details."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { await client.count == 1 }
    await client.finish("🔍 Детали, детали.", request: 0)
    try await waitUntil { store.isComplete }
    let id = store.requestID
    let second = (store.translatedText as NSString).range(of: "детали")
    let word = try #require(TranslationWord(text: store.translatedText, characterOffset: second.location + 1, language: "ru"))
    store.replace(try #require(word.alternative(replacement: "нюансы")), id: id)
    #expect(store.translatedText == "🔍 Детали, нюансы.")
    store.sourceText += "\nMore."
    store.schedule(preferences: preferences, immediately: true)
    store.replace(try #require(word.alternative(replacement: "лишнее")), id: id)
    try await waitUntil { await client.count == 2 }
    await client.finish("\nЕщё.", request: 1)
    try await waitUntil { store.isComplete }
    #expect(store.translatedText == "🔍 Детали, нюансы.\nЕщё.")
    store.sourceText = "Details, details."
    store.schedule(preferences: preferences, immediately: true)
    try await waitUntil { store.isComplete }
    #expect(store.translatedText == "🔍 Детали, нюансы.")
    #expect(await client.count == 2)
}

@Test func clickedWordLimitsContextAndFiltersModelOutput() throws {
    let text = "Private paragraph.\n👩🏽‍💻 Café has good coffee.\nPrivate footer."
    let location = (text as NSString).range(of: "good").location
    let word = try #require(TranslationWord(text: text, characterOffset: location + 2, language: "en"))
    #expect(word.before == "👩🏽‍💻 Café has ")
    #expect(word.after == " coffee.")
    #expect(TranslationWord(text: text, characterOffset: location - 1, language: "en") == nil)
    #expect(TranslationWord(text: text, characterOffset: (text as NSString).range(of: "footer.").location + 6, language: "en") == nil)
    let raw = ["GOOD", "decent", "Decent", " fine ", "multi\nline", "", "123"]
    let response = try JSONEncoder().encode(raw.map { ["left": "", "right": "", "replacement": $0] })
    #expect(try word.suggestions(from: String(decoding: response, as: UTF8.self)).map(\.replacement) == ["decent", "fine"])
    #expect(throws: TranslationError.invalidResponse) { try word.suggestions(from: "[\"unfinished") }
}

@Test(arguments: [
    ("I saw an apartment and an apartment.", "apartment", "an ", "", "a flat", "I saw an apartment and a flat."),
    ("She found a flat.", "flat", "a ", "", "an apartment", "She found an apartment."),
    ("Это тихое место рядом.", "место", "тихое ", "", "тихий уголок", "Это тихий уголок рядом."),
    ("Une idée originale.", "idée", "Une ", " originale", "Un concept original", "Un concept original."),
    ("J’aime l’école.", "école", "l’", "", "la classe", "J’aime la classe.")
]) func agreementEditPreservesEverythingOutsideTheExactSpan(text: String, token: String, left: String, right: String,
                                                            replacement: String, expected: String) throws {
    let occurrence = (text as NSString).range(of: token, options: .backwards)
    let word = try #require(TranslationWord(text: text, characterOffset: occurrence.location, language: Languages.detect(text) ?? "en"))
    // The tokenizer may include an attached apostrophe and article in a single French token.
    let actualLeft = word.word == left + token ? "" : left
    let edit = try #require(word.alternative(left: actualLeft, right: right, replacement: replacement))
    #expect((text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) == expected)
    #expect(word.alternative(left: "invented ", replacement: replacement) == nil)
    #expect(word.alternative(right: "\n", replacement: replacement) == nil)
}

@Test func incompleteModelSpanCannotLeaveTwoArticlesOrAnInvalidArticle() throws {
    let text = "I saw an apartment."
    let word = try #require(TranslationWord(text: text, characterOffset: 10, language: "en"))
    let response = #"[{"left":"","right":"","replacement":"a flat"},{"left":"","right":"","replacement":"flat"}]"#
    let choices = try word.suggestions(from: response)
    #expect(choices.count == 1)
    let choice = try #require(choices.first)
    #expect((text as NSString).replacingCharacters(in: choice.range, with: choice.replacement) == "I saw a flat.")
}

@Test func repeatedListContextIsKeptOutsideWordReplacements() throws {
    let text = "Check, one, two, suitcase, please."
    let range = (text as NSString).range(of: "suitcase")
    let word = try #require(TranslationWord(text: text, characterOffset: range.location, language: "en"))
    let response = #"""
    [
        {"left":"two, ","right":"","replacement":"two, bag"},
        {"left":"","right":", please.","replacement":"travel case, please."},
        {"left":"one, two, ","right":", please.","replacement":"one, two, travel bag, please."},
        {"left":"two, ","right":"","replacement":"two, BAG"},
        {"left":"other, ","right":"","replacement":"other, kit"},
        {"left":"two, ","right":"","replacement":"case"}
    ]
    """#
    let edits = try word.suggestions(from: response)
    #expect(edits.map(\.replacement) == ["bag", "travel case", "travel bag"])
    #expect(edits.allSatisfy { $0.range == range })
    let first = try #require(edits.first)
    #expect((text as NSString).replacingCharacters(in: first.range, with: first.replacement) == "Check, one, two, bag, please.")
    #expect(try word.suggestions(from: "[]").isEmpty)
    #expect(throws: WordSuggestionsError.unusableEdits) {
        try word.suggestions(from: #"[{"left":"two, ","right":"","replacement":"one, case"}]"#)
    }
}

@Test func repeatedContextKeepsTheArticleAndAgreementInsideTheEdit() throws {
    let text = "📍 Here, an apartment."
    let word = try #require(TranslationWord(text: text, characterOffset: (text as NSString).range(of: "apartment").location, language: "en"))
    let edits = try word.suggestions(from: #"[{"left":"📍 Here, an ","right":".","replacement":"📍 Here, a flat."}]"#)
    let edit = try #require(edits.first)
    #expect(edit.original == "an apartment")
    #expect(edit.replacement == "a flat")
    #expect((text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) == "📍 Here, a flat.")
}

@MainActor @Test func textViewAnchorsSuggestionsToTheClickedOccurrence() throws {
    let view = TranslationTextView(frame: NSRect(x: 0, y: 0, width: 340, height: 140))
    view.font = NSFont.systemFont(ofSize: 17)
    view.textContainerInset = NSSize(width: 22, height: 20)
    view.string = "A place.\nA quiet place."
    let layout = try #require(view.layoutManager)
    let container = try #require(view.textContainer)
    layout.ensureLayout(for: container)
    let second = (view.string as NSString).range(of: "place", options: .backwards)
    let glyphs = layout.glyphRange(forCharacterRange: second, actualCharacterRange: nil)
    let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
        .offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
    let hit = try #require(view.word(at: NSPoint(x: rect.midX, y: rect.midY), language: "en"))
    #expect(hit.word.range == second)
    #expect(hit.rect == rect)
    #expect(view.isFlipped)
    #expect(view.word(at: NSPoint(x: rect.maxX + 80, y: rect.midY), language: "en") == nil)
}

@MainActor @Test func wordSuggestionsForClicksInACommaSeparatedList() throws {
    let view = TranslationTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
    view.string = "Check, one, two, three"
    let layout = try #require(view.layoutManager)
    let container = try #require(view.textContainer)
    layout.ensureLayout(for: container)

    for token in ["one", "two", "three"] {
        let range = (view.string as NSString).range(of: token)
        let glyph = layout.glyphIndexForCharacter(at: range.location)
        let rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        let point = NSPoint(x: rect.midX + view.textContainerOrigin.x, y: rect.midY + view.textContainerOrigin.y)
        let hit = try #require(view.word(at: point, language: "en"))
        let payload = try JSONDecoder().decode([String: String].self, from: Data(hit.word.payload().utf8))
        #expect(payload["word"] == token)
        #expect(payload["articleBefore"] == nil)
        let edits = try hit.word.suggestions(from: #"[{"left":"","right":"","replacement":"next"}]"#)
        #expect(edits.first?.range == range)
    }
}

@Test(arguments: [
    ("", nil), ("   ", nil), ("line\n", nil), ("… ", nil), ("4\t", nil),
    ("🎙️  ", nil), ("an, ", nil), ("theatre ", nil), ("A ", "A "),
    ("after an\u{00a0}", "an\u{00a0}"), ("(THE  ", "THE  ")
] as [(String, String?)])
func englishArticleContextBeforeClickedWord(prefix: String, article: String?) throws {
    let word = try #require(TranslationWord(text: prefix + "example", characterOffset: prefix.utf16.count, language: "en"))
    let payload = try JSONDecoder().decode([String: String].self, from: Data(word.payload().utf8))
    #expect(payload["articleBefore"] == article)
}
