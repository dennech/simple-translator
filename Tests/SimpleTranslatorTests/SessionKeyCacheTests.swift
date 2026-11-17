import Testing
@testable import SimpleTranslator

@Test func credentialIsReadOncePerProviderUntilRemoved() throws {
    let cache = SessionKeyCache()
    var reads = 0
    let load = { reads += 1; return "synthetic-key-\(reads)" }
    #expect(cache.read(.deepL, load: load) == "synthetic-key-1")
    #expect(cache.read(.deepL, load: load) == "synthetic-key-1")
    #expect(reads == 1)
    #expect(cache.read(.openAI, load: load) == "synthetic-key-2")
    cache.set("synthetic-replacement", for: .deepL)
    #expect(cache.read(.deepL, load: load) == "synthetic-replacement")
    #expect(reads == 2)
    cache.set(nil, for: .deepL)
    #expect(cache.read(.deepL, load: load) == "synthetic-key-3")
}

@Test func declinedKeychainAccessCanBeRetriedWithoutCachingFailure() throws {
    let cache = SessionKeyCache()
    #expect(throws: TranslationError.missingKey) {
        try cache.read(.deepL) { throw TranslationError.missingKey }
    }
    #expect(cache.read(.deepL) { nil } == nil)
    #expect(cache.read(.deepL) { "synthetic-retry" } == "synthetic-retry")
}
