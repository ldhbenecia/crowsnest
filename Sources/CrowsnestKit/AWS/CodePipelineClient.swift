import Foundation

/// CodePipeline JSON API 를 서명해서 직접 부름 — 응답 모양은 aws CLI 의 --output json 과 같음
struct CodePipelineClient: Sendable {
    let credentials: CredentialCache

    /// 쿠키 · 캐시를 디스크에 안 남기게 ephemeral
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    func call<Request: Encodable, Response: Decodable>(
        _ operation: String,
        _ request: Request,
        profile: String,
        region: String,
        as response: Response.Type
    ) async throws -> Response {
        let used = try await credentials.credentials(for: profile)
        do {
            return try await send(operation, request, profile: profile, region: region, credentials: used)
        } catch let error as AWSError where error.kind == .expiredSession {
            // 임시 키가 예정보다 일찍 끊긴 경우 — 한 번만 새로 받아서 다시 해봄
            await credentials.invalidate(profile, rejected: used)
            let renewed = try await credentials.credentials(for: profile)
            return try await send(operation, request, profile: profile, region: region, credentials: renewed)
        }
    }

    private func send<Request: Encodable, Response: Decodable>(
        _ operation: String,
        _ request: Request,
        profile: String,
        region: String,
        credentials: AWSCredentials
    ) async throws -> Response {
        // 리전이 URL 호스트에 들어가서 이상한 값이면 서명된 요청이 엉뚱한 곳으로 나감
        guard region.wholeMatch(of: /[a-z]{2}(-[a-z]+)+-\d+/) != nil,
              let url = URL(string: "https://codepipeline.\(region).amazonaws.com/") else {
            throw AWSError(profile: profile, kind: .other, detail: "리전 이름이 이상함 · \(region)")
        }
        let body = try JSONEncoder().encode(request)
        let signer = SignatureV4(credentials: credentials, region: region, service: "codepipeline")
        let headers = signer.signedHeaders(
            method: "POST",
            url: url,
            headers: [
                "content-type": "application/x-amz-json-1.1",
                "x-amz-target": "CodePipeline_20150709.\(operation)",
            ],
            body: body,
            date: .now
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        for (name, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, urlResponse) = try await Self.session.data(for: urlRequest)
        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let failure = try? JSONDecoder().decode(ServiceFailure.self, from: data)
            let code = failure?.code ?? "HTTP \((urlResponse as? HTTPURLResponse)?.statusCode ?? 0)"
            throw AWSError.service(profile: profile, code: code, message: failure?.message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

/// {"__type": "com.amazonaws.codepipeline#PipelineNotFoundException", "message": "..."}
private struct ServiceFailure: Decodable {
    let type: String?
    let lowercaseMessage: String?
    let capitalizedMessage: String?

    enum CodingKeys: String, CodingKey {
        case type = "__type"
        case lowercaseMessage = "message"
        case capitalizedMessage = "Message"
    }

    var code: String? { type.map { String($0.split(separator: "#").last ?? Substring($0)) } }
    var message: String? { lowercaseMessage ?? capitalizedMessage }
}
