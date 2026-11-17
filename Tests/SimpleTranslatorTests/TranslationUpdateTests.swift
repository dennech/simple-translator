import Testing
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
