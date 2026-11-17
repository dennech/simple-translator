import Foundation
import CryptoKit

enum AWSSigner {
    static let regions: Set<String> = ["us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "ca-west-1",
        "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-central-2", "eu-north-1", "eu-south-1", "eu-south-2",
        "ap-south-1", "ap-south-2", "ap-southeast-1", "ap-southeast-2", "ap-southeast-3", "ap-southeast-4",
        "ap-northeast-1", "ap-northeast-2", "ap-northeast-3", "sa-east-1", "af-south-1", "me-south-1", "me-central-1", "il-central-1"]

    static func request(text: String, source: String, target: String, region: String,
                        credentials: AWSCredentials, date: Date = Date()) throws -> URLRequest {
        guard regions.contains(region) else { throw TranslationError.missingParameters }
        let host = "translate.\(region).amazonaws.com"
        var request = URLRequest(url: URL(string: "https://\(host)/")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Text": text, "SourceLanguageCode": source, "TargetLanguageCode": target], options: [.sortedKeys])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let timestamp = formatter.string(from: date)
        let day = String(timestamp.prefix(8))
        var headers = ["content-type": "application/x-amz-json-1.1", "host": host, "x-amz-date": timestamp,
                       "x-amz-target": "AWSShineFrontendService_20170701.TranslateText"]
        if !credentials.sessionToken.isEmpty { headers["x-amz-security-token"] = credentials.sessionToken }
        let names = headers.keys.sorted()
        let signedHeaders = names.joined(separator: ";")
        let canonicalHeaders = names.map { "\($0):\(headers[$0]!.trimmingCharacters(in: .whitespacesAndNewlines))\n" }.joined()
        let canonical = "POST\n/\n\n\(canonicalHeaders)\n\(signedHeaders)\n\(hash(request.httpBody!))"
        let scope = "\(day)/\(region)/translate/aws4_request"
        let stringToSign = "AWS4-HMAC-SHA256\n\(timestamp)\n\(scope)\n\(hash(Data(canonical.utf8)))"
        let dayKey = hmac(Data(("AWS4" + credentials.secretKey).utf8), day)
        let regionKey = hmac(dayKey, region)
        let serviceKey = hmac(regionKey, "translate")
        let signingKey = hmac(serviceKey, "aws4_request")
        let signature = hmac(signingKey, stringToSign).map { String(format: "%02x", $0) }.joined()
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("AWS4-HMAC-SHA256 Credential=\(credentials.accessKey)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)", forHTTPHeaderField: "Authorization")
        return request
    }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func hmac(_ key: Data, _ value: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: SymmetricKey(data: key)))
    }
}
