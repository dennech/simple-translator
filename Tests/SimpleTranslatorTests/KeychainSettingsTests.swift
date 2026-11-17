import Testing
import Security
import LocalAuthentication
@testable import SimpleTranslator

@Test func settingsCheckOnlyMetadataWithAuthenticationDisabled() {
    let state = Keychain.savedState(.deepL) { query in
        #expect(query[kSecReturnData as String] == nil)
        #expect(query[kSecReturnAttributes as String] as? Bool == true)
        #expect((query[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed == true)
        return errSecSuccess
    }
    #expect(state == .stored)
    #expect(Keychain.savedState(.deepL) { _ in errSecItemNotFound } == .missing)
    #expect(Keychain.savedState(.deepL) { _ in errSecInteractionNotAllowed } == .unavailable)
}

@Test func publicAndStaticModelListsDoNotNeedCredentials() {
    #expect(!Provider.deepL.modelListRequiresKey)
    #expect(!Provider.openRouter.modelListRequiresKey)
    #expect(Provider.openAI.modelListRequiresKey)
    #expect(Provider.gemini.modelListRequiresKey)
}
