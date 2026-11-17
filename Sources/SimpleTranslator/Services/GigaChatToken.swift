import Foundation
import CryptoKit

final class GigaChatToken: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = UUID()
    private var cached: (fingerprint: Data, scope: String, token: String, expiry: Date)?

    func invalidate() {
        lock.withLock { cached = nil; generation = UUID() }
    }

    func accessToken(credential: String, scope: String, session: URLSession) async throws -> String {
        let fingerprint = Data(SHA256.hash(data: Data(credential.utf8)))
        let (ticket, existing): (UUID, String?) = lock.withLock {
            let token = cached.flatMap {
                $0.fingerprint == fingerprint && $0.scope == scope && $0.expiry.timeIntervalSinceNow > 60 ? $0.token : nil
            }
            return (generation, token)
        }
        if let existing { return existing }
        let request = try Self.request(credential: credential, scope: scope)
        let (data, response) = try await session.data(for: request)
        try TranslationClient.validate(response)
        struct Response: Decodable { let access_token: String; let expires_at: Double }
        let result = try JSONDecoder().decode(Response.self, from: data)
        guard !result.access_token.isEmpty else { throw TranslationError.invalidResponse }
        let seconds = result.expires_at > 100_000_000_000 ? result.expires_at / 1000 : result.expires_at
        let expiry = min(Date(timeIntervalSince1970: seconds), Date().addingTimeInterval(25 * 60))
        guard expiry > Date() else { throw TranslationError.invalidResponse }
        try Task.checkCancellation()
        try lock.withLock {
            guard generation == ticket else { throw CancellationError() }
            cached = (fingerprint, scope, result.access_token, expiry)
        }
        return result.access_token
    }

    static func request(credential: String, scope: String) throws -> URLRequest {
        guard ["GIGACHAT_API_PERS", "GIGACHAT_API_B2B", "GIGACHAT_API_CORP"].contains(scope) else { throw TranslationError.missingParameters }
        guard !credential.isEmpty else { throw TranslationError.missingKey }
        var request = URLRequest(url: URL(string: "https://ngw.devices.sberbank.ru:9443/api/v2/oauth")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "RqUID")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data("scope=\(scope)".utf8)
        return request
    }
}
