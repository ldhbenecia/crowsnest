import Foundation

/// 메모리에만 들고 있음 — 디스크 · 로그에 남기지 않음
struct AWSCredentials: Decodable, Sendable, CustomStringConvertible {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String?
    /// IAM 사용자 키처럼 만료가 없으면 nil
    let expiration: Date?

    /// 실수로 로그 · 에러 문구에 찍혀도 키가 안 나가게
    var description: String { "AWSCredentials(<redacted>)" }
}

/// aws configure export-credentials --format process 출력
extension AWSCredentials {
    enum CodingKeys: String, CodingKey {
        case accessKeyId = "AccessKeyId"
        case secretAccessKey = "SecretAccessKey"
        case sessionToken = "SessionToken"
        case expiration = "Expiration"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessKeyId = try container.decode(String.self, forKey: .accessKeyId)
        secretAccessKey = try container.decode(String.self, forKey: .secretAccessKey)
        sessionToken = try container.decodeIfPresent(String.self, forKey: .sessionToken)
        expiration = try container.decodeIfPresent(String.self, forKey: .expiration).flatMap(AWSTimestamp.parse)
    }
}

/// 프로필마다 aws configure export-credentials 를 만료될 때만 다시 부름 — 폴링마다 aws 프로세스를 띄우지 않으려고
actor CredentialCache {
    private struct Entry {
        let credentials: AWSCredentials
        let refreshAfter: Date
    }

    /// 만료 직전 요청이 서명 도중에 끊기지 않게 여유를 둠
    private static let expirationMargin: TimeInterval = 5 * 60
    /// 만료가 없는 키도 바뀌었을 수 있어서 가끔 다시 읽음
    private static let staticKeyLifetime: TimeInterval = 60 * 60

    /// SSO 가 만료되면 로그인할 때까지 계속 실패하니 그동안 aws 를 다시 띄우지 않음
    private static let failureLifetime: TimeInterval = 5 * 60

    private let cli: AWSCommandLine
    private var entries: [String: Entry] = [:]
    private var failures: [String: (error: any Error, retryAfter: Date)] = [:]
    private var pending: [String: Task<AWSCredentials, any Error>] = [:]

    init(cli: AWSCommandLine) {
        self.cli = cli
    }

    func credentials(for profile: String) async throws -> AWSCredentials {
        if let entry = entries[profile], entry.refreshAfter > .now {
            return entry.credentials
        }
        if let failure = failures[profile], failure.retryAfter > .now {
            throw failure.error
        }
        // 파이프라인 여러 개가 같은 프로필을 동시에 물어도 aws 는 한 번만 띄움
        if let task = pending[profile] {
            return try await task.value
        }
        let task = Task { [cli] in
            let output = try await cli.run(["configure", "export-credentials", "--profile", profile, "--format", "process"], profile: profile)
            return try JSONDecoder().decode(AWSCredentials.self, from: output)
        }
        pending[profile] = task
        defer { pending[profile] = nil }
        do {
            let credentials = try await task.value
            let refreshAfter = credentials.expiration.map { $0.addingTimeInterval(-Self.expirationMargin) }
                ?? Date.now.addingTimeInterval(Self.staticKeyLifetime)
            entries[profile] = Entry(credentials: credentials, refreshAfter: refreshAfter)
            failures[profile] = nil
            return credentials
        } catch {
            failures[profile] = (error, Date.now.addingTimeInterval(Self.failureLifetime))
            throw error
        }
    }

    /// 서버가 토큰을 거절했을 때 — 다음 요청에서 새로 받음
    /// 파이프라인 여러 개가 동시에 거절당하면 먼저 새로 받아둔 걸 지우지 않게 거절당한 키일 때만 지움
    func invalidate(_ profile: String, rejected: AWSCredentials) {
        guard let current = entries[profile]?.credentials,
              current.accessKeyId == rejected.accessKeyId, current.sessionToken == rejected.sessionToken else { return }
        entries[profile] = nil
    }

    /// 새로고침 버튼 — 방금 로그인했을 수 있어서 실패 기억을 지움
    func forgetFailures() {
        failures.removeAll()
    }
}
