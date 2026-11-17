import Foundation
import Security
import LocalAuthentication

enum SavedKeyState {
    case stored, missing, unavailable
}

enum Keychain {
    private static let service = "app.simpletranslator.mac.apikey"
    private static let session = SessionKeyCache()

    /// Metadata only. Settings must never unlock or read the credential just to show its status.
    static func savedState(_ provider: Provider,
                           lookup: ([String: Any]) -> OSStatus = { SecItemCopyMatching($0 as CFDictionary, nil) }) -> SavedKeyState {
        var query = baseQuery(provider)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        switch lookup(query) {
        case errSecSuccess: return .stored
        case errSecItemNotFound: return .missing
        default: return .unavailable
        }
    }

    static func read(_ provider: Provider) throws -> String? {
        try session.read(provider) { try readStored(provider) }
    }

    private static func readStored(_ provider: Provider) throws -> String? {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw KeychainError(status: status) }
        return value
    }

    static func save(_ key: String, for provider: Provider) throws {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { try delete(provider); return }
        let query = baseQuery(provider)
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            var item = query.merging(attributes) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            item[kSecAttrSynchronizable as String] = false
            item[kSecAttrLabel as String] = "Простой переводчик · \(provider.title)"
            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError(status: status) }
        } else if update != errSecSuccess { throw KeychainError(status: update) }
        session.set(value, for: provider)
        TranslationClient.shared.invalidateCredential(for: provider)
    }

    static func delete(_ provider: Provider) throws {
        session.set(nil, for: provider)
        TranslationClient.shared.invalidateCredential(for: provider)
        let status = SecItemDelete(baseQuery(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private static func baseQuery(_ provider: Provider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: provider.rawValue]
    }
}

/// Keeps an already authorized credential in process memory until exit, replacement or deletion.
/// Serializes first reads so simultaneous requests cannot create multiple Keychain prompts.
final class SessionKeyCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Provider: String] = [:]

    func read(_ provider: Provider, load: () throws -> String?) rethrows -> String? {
        try lock.withLock {
            if let value = values[provider] { return value }
            let value = try load()
            values[provider] = value
            return value
        }
    }

    func set(_ value: String?, for provider: Provider) {
        lock.withLock { values[provider] = value }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Не удалось открыть Связку ключей (\(status)). Разблокируйте её и попробуйте снова." }
}
