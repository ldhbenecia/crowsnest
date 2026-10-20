import CryptoKit
import Foundation

/// AWS 요청 서명 (Signature Version 4) — SDK 없이 API 를 부르려고 직접 함
struct SignatureV4 {
    let credentials: AWSCredentials
    let region: String
    let service: String

    /// 서명에 들어간 헤더를 포함해 요청에 붙일 헤더 전부를 돌려줌
    func signedHeaders(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data,
        date: Date
    ) -> [String: String] {
        let amazonDate = Self.amazonTimestamp(date)
        let dateStamp = String(amazonDate.prefix(8))

        var headers = headers
        headers["host"] = url.host(percentEncoded: true)
        headers["x-amz-date"] = amazonDate
        if let sessionToken = credentials.sessionToken {
            headers["x-amz-security-token"] = sessionToken
        }
        let canonicalHeaders = headers
            .map { (name: $0.key.lowercased(), value: $0.value.trimmingCharacters(in: .whitespaces)) }
            .sorted { $0.name < $1.name }
        let signedHeaderNames = canonicalHeaders.map(\.name).joined(separator: ";")

        // 쿼리 없는 요청만 보내서 정규 쿼리는 늘 빈 줄
        let canonicalRequest = [
            method,
            url.path(percentEncoded: true).isEmpty ? "/" : url.path(percentEncoded: true),
            "",
            canonicalHeaders.map { "\($0.name):\($0.value)\n" }.joined(),
            signedHeaderNames,
            Self.hexDigest(body),
        ].joined(separator: "\n")

        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = ["AWS4-HMAC-SHA256", amazonDate, scope, Self.hexDigest(Data(canonicalRequest.utf8))]
            .joined(separator: "\n")

        var key = SymmetricKey(data: Data("AWS4\(credentials.secretAccessKey)".utf8))
        for part in [dateStamp, region, service, "aws4_request"] {
            key = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(part.utf8), using: key)))
        }
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key).hexString

        headers["authorization"] = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyId)/\(scope), "
            + "SignedHeaders=\(signedHeaderNames), Signature=\(signature)"
        return headers
    }

    private static func hexDigest(_ data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    /// 20150830T123600Z — 요청마다 DateFormatter 를 만들지 않게 한 번만 둠
    private static let amazonTimestampStyle = Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted, timeZone: .gmt)

    private static func amazonTimestamp(_ date: Date) -> String {
        date.formatted(amazonTimestampStyle)
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
