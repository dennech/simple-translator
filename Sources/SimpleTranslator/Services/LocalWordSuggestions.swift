#if canImport(FoundationModels)
import FoundationModels
#endif
import Foundation

enum LocalWordSuggestions {
    static func alternatives(for word: TranslationWord, language: String) async throws -> [WordAlternative] {
        #if canImport(FoundationModels) && arch(arm64)
        if #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable,
           SystemLanguageModel.default.supportsLocale(Locale(identifier: language)) {
            let session = LanguageModelSession(instructions: TranslationWord.instructions(language: language))
            let response = try await session.respond(to: word.payload())
            try Task.checkCancellation()
            return try word.suggestions(from: response.content)
        }
        #endif
        throw WordSuggestionsError.needsProvider
    }
}
