import Foundation
import Testing
@testable import SimpleTranslator

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (Int, String)
    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]
    static func install(_ id: String, handler: @escaping Handler) { lock.withLock { handlers[id] = handler } }
    static func remove(_ id: String) { _ = lock.withLock { handlers.removeValue(forKey: id) } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let id = request.value(forHTTPHeaderField: "X-Fixture-ID") ?? ""
            guard let handler = Self.lock.withLock({ Self.handlers[id] }) else { throw URLError(.badURL) }
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": body.hasPrefix("data:") ? "text/event-stream" : "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

private final class RecordedRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    func append(_ request: URLRequest) { lock.withLock { items.append(request) } }
    var all: [URLRequest] { lock.withLock { items } }
}

@Test(arguments: Provider.allCases) func cloudProviderAcceptsItsDocumentedResponse(_ provider: Provider) async throws {
    let id = UUID().uuidString
    let recorded = RecordedRequests()
    FixtureProtocol.install(id) { request in
        recorded.append(request)
        #expect(request.url?.scheme == "https")
        #expect(!(request.url?.absoluteString.contains("synthetic-secret") ?? false))
        if request.url?.path == "/api/v2/oauth" {
            return (200, "{\"access_token\":\"synthetic-access\",\"expires_at\":\(Int(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000))}")
        }
        switch provider {
        case .deepL, .yandex: return (200, #"{"translations":[{"text":"Привет."}]}"#)
        case .azure: return (200, #"[{"translations":[{"text":"Привет.","to":"ru"}]}]"#)
        case .googleCloud: return (200, #"{"data":{"translations":[{"translatedText":"Привет."}]}}"#)
        case .myMemory: return (200, #"{"responseStatus":200,"responseData":{"translatedText":"Привет."},"quotaFinished":false}"#)
        case .amazon: return (200, #"{"TranslatedText":"Привет."}"#)
        case .sambaNova: return (200, #"{"choices":[{"message":{"content":"Привет."},"finish_reason":"stop"}]}"#)
        default: return (200, "data: {\"choices\":[{\"delta\":{\"content\":\"Привет.\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n")
        }
    }
    defer { FixtureProtocol.remove(id) }
    let sessionOptions = URLSessionConfiguration.ephemeral
    sessionOptions.protocolClasses = [FixtureProtocol.self]
    sessionOptions.httpAdditionalHeaders = ["X-Fixture-ID": id]
    let session = URLSession(configuration: sessionOptions)
    defer { session.invalidateAndCancel() }
    let client = TranslationClient(session: session)
    let options = ConnectionOptions(accountID: String(repeating: "a", count: 32), region: "us-east-1", scope: "GIGACHAT_API_PERS")
    let key = provider == .amazon ? try AWSCredentials(accessKey: "SYNTHETICACCESS", secretKey: "synthetic-secret", sessionToken: "").encoded() : provider == .myMemory ? "" : "synthetic-secret"
    let config = TranslationConfiguration(provider: provider, model: provider == .huggingFace ? "example/model:novita" : "synthetic-model", key: key, source: "en", target: "ru", options: options)
    let result = try await client.translate("Hello.", configuration: config) { _ in }
    #expect(result == "Привет.")
    if provider == .gigaChat {
        _ = try await client.translate("Hello again.", configuration: config) { _ in }
        #expect(recorded.all.filter { $0.url?.path == "/api/v2/oauth" }.count == 1)
        #expect(recorded.all.last?.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-access")
        client.invalidateCredential(for: .gigaChat)
        _ = try await client.translate("After replacement.", configuration: config) { _ in }
        #expect(recorded.all.filter { $0.url?.path == "/api/v2/oauth" }.count == 2)
    }
}

@Test func specializedRequestsKeepSecretsOutOfURLAndBody() throws {
    for provider in [Provider.azure, .googleCloud, .yandex] {
        let config = TranslationConfiguration(provider: provider, model: "standard", key: "synthetic-secret", source: "auto", target: "ru")
        let request = try ProviderRequests.specialized("Hello", configuration: config)
        #expect(!(request.url?.absoluteString.contains("synthetic-secret") ?? false))
        #expect(!String(decoding: request.httpBody ?? Data(), as: UTF8.self).contains("synthetic-secret"))
        #expect(request.httpMethod == "POST")
        if provider == .googleCloud { #expect(request.value(forHTTPHeaderField: "X-Goog-Api-Key") == "synthetic-secret") }
        if provider == .yandex { #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains("folderId")) }
    }
    #expect(throws: TranslationError.missingParameters) {
        try ProviderRequests.chatURL(.cloudflare, options: ConnectionOptions(accountID: "../attacker.example", region: "", scope: ""))
    }
}

@Test func awsSignatureMatchesIndependentHMACVector() throws {
    let credentials = AWSCredentials(accessKey: "SYNTHETICACCESS", secretKey: "synthetic-secret", sessionToken: "synthetic-session")
    let request = try AWSSigner.request(text: "Hello", source: "en", target: "ru", region: "us-east-1", credentials: credentials, date: Date(timeIntervalSince1970: 1_700_000_000))
    let auth = try #require(request.value(forHTTPHeaderField: "Authorization"))
    #expect(auth.hasSuffix("Signature=c58f8ef786a5bfc2b46769a6bceb50596f355cf77d18a76fc644aada2f3594c3"))
    #expect(auth.contains("x-amz-security-token"))
    #expect(!auth.contains(credentials.secretKey))
    #expect(throws: TranslationError.missingParameters) {
        try AWSSigner.request(text: "Hello", source: "en", target: "ru", region: "attacker.example", credentials: credentials)
    }
}

@Test func byteLimitedChunksPreserveUnicodeAndParagraphs() throws {
    let text = String(repeating: "Привет! 👨‍👩‍👧‍👦 漢字\n\n", count: 150)
    let chunks = try TextChunker.splitUTF8(text, limit: 500, oneLine: true)
    #expect(chunks.joined() == text)
    #expect(chunks.allSatisfy { $0.utf8.count <= 500 })
    let aws = try TextChunker.splitUTF8(text, limit: 10_000)
    #expect(aws.joined() == text && aws.allSatisfy { $0.utf8.count <= 10_000 })
}

@Test func catalogFormatsAndFixedRoutesArePreserved() throws {
    let together = try ModelCatalog.parse(Data(#"[{"id":"example/text-model","type":"chat"}]"#.utf8), provider: .together)
    #expect(together.map(\.id) == ["example/text-model"])
    let fireworks = try ModelCatalog.parse(Data(#"{"models":[{"name":"accounts/fireworks/models/example","supportsServerless":true}]}"#.utf8), provider: .fireworks)
    #expect(fireworks.count == 1)
    let hf = try ModelCatalog.parse(Data(#"{"data":[{"id":"example/model","architecture":{"output_modalities":["text"]},"providers":[{"provider":"novita","status":"live"},{"provider":"auto","status":"live"},{"provider":"other","status":"offline"}]}]}"#.utf8), provider: .huggingFace)
    #expect(hf.map(\.id) == ["example/model:novita"])
    #expect(!hf[0].isFree)
    for model in ["example/model", "example/model:auto", "example/model:cheapest"] {
        #expect(throws: TranslationError.missingParameters) {
            try ProviderRequests.validateModel(TranslationConfiguration(provider: .huggingFace, model: model, key: "synthetic", source: "en", target: "ru"))
        }
    }
}

@Test func errorPayloadsAndHTMLAreHandledWithoutExposingRemoteDetails() throws {
    #expect(throws: TranslationError.server(429)) {
        try ProviderRequests.translatedText(Data(#"{"responseStatus":200,"quotaFinished":true,"responseDetails":"synthetic-sensitive-text"}"#.utf8), provider: .myMemory)
    }
    let result = try ProviderRequests.translatedText(Data(#"{"data":{"translations":[{"translatedText":"A &amp; B: &#x41; &quot;C&quot;"}]}}"#.utf8), provider: .googleCloud)
    #expect(result == "A & B: A \"C\"")
}

@Test(arguments: Provider.allCases.filter { !$0.isSpecialized }) func contextualAlternativesUseChosenAPI(_ provider: Provider) async throws {
    let id = UUID().uuidString
    FixtureProtocol.install(id) { request in
        if request.url?.path == "/api/v2/oauth" {
            return (200, "{\"access_token\":\"synthetic-access\",\"expires_at\":\(Int(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000))}")
        }
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 2048)
            while true {
                let size = stream.read(&buffer, maxLength: buffer.count)
                guard size >= 0 else { throw URLError(.cannotDecodeRawData) }
                if size == 0 { break }
                data.append(contentsOf: buffer.prefix(size))
            }
        }
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["stream"] as? Bool == false)
        let messages = try #require(body["messages"] as? [[String: String]])
        let context = try JSONDecoder().decode([String: String].self, from: Data((messages.last?["content"] ?? "").utf8))
        #expect(context == ["before": "a ", "word": "quiet", "after": " place", "articleBefore": "a "])
        if provider == .openAI { #expect(body["store"] as? Bool == false) }
        if provider == .openRouter { #expect((body["provider"] as? [String: String])?["data_collection"] == "deny") }
        let edits = [["left": "a ", "right": "", "replacement": "a peaceful"], ["left": "a ", "right": "", "replacement": "a calm"]]
        let content = String(decoding: try JSONEncoder().encode(edits), as: UTF8.self)
        let reply = ["choices": [["message": ["content": content], "finish_reason": "stop"]]]
        return (200, String(decoding: try JSONSerialization.data(withJSONObject: reply), as: UTF8.self))
    }
    defer { FixtureProtocol.remove(id) }
    let options = URLSessionConfiguration.ephemeral
    options.protocolClasses = [FixtureProtocol.self]
    options.httpAdditionalHeaders = ["X-Fixture-ID": id]
    let session = URLSession(configuration: options)
    defer { session.invalidateAndCancel() }
    let config = TranslationConfiguration(provider: provider, model: provider == .huggingFace ? "sample/model:novita" : "sample",
        key: "synthetic", source: "en", target: "en", options: ConnectionOptions(accountID: String(repeating: "a", count: 32)))
    let word = try #require(TranslationWord(text: "a quiet place", characterOffset: 3, language: "en"))
    let result = try await TranslationClient(session: session).alternatives(for: word, configuration: config)
    #expect(result.map(\.replacement) == ["a peaceful", "a calm"])
}

@Test func incompleteOrFailedAlternativesNeverBecomeReplacements() async throws {
    let options = URLSessionConfiguration.ephemeral
    options.protocolClasses = [FixtureProtocol.self]
    let id = UUID().uuidString
    options.httpAdditionalHeaders = ["X-Fixture-ID": id]
    let session = URLSession(configuration: options)
    defer { session.invalidateAndCancel(); FixtureProtocol.remove(id) }
    let client = TranslationClient(session: session)
    let config = TranslationConfiguration(provider: .openAI, model: "sample", key: "synthetic", source: "en", target: "en")
    let word = try #require(TranslationWord(text: "calm", characterOffset: 0, language: "en"))
    FixtureProtocol.install(id) { _ in (200, #"{"choices":[{"finish_reason":"length","message":{"content":"[\"still\"]"}}]}"#) }
    await #expect(throws: TranslationError.truncated) { try await client.alternatives(for: word, configuration: config) }
    FixtureProtocol.install(id) { _ in (403, "synthetic private response") }
    do {
        _ = try await client.alternatives(for: word, configuration: config)
        Issue.record("Expected a rejected request")
    } catch {
        #expect(error as? TranslationError == .server(403))
        #expect(!TranslationError.message(for: error).contains("synthetic"))
    }
    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await client.alternatives(for: word, configuration: config)
    }
    await #expect(throws: CancellationError.self) { try await cancelled.value }
}
