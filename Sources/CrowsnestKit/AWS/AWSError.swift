import Foundation

/// aws CLI 와 API 직접 호출이 같은 안내 문구를 쓰게 한 곳에서 판별
struct AWSError: LocalizedError, Sendable, Equatable {
    enum Kind: Equatable, Sendable {
        case expiredSession
        case missingCredentials
        case accessDenied
        case pipelineNotFound
        case other
    }

    let profile: String?
    let kind: Kind
    /// .other 일 때 그대로 보여줄 한 줄
    let detail: String

    /// 서비스 에러는 "An error occurred (Code) when calling ..." 로 코드가 오고,
    /// SSO · 자격 증명 에러는 CLI 가 요청 전에 내는 거라 문장으로만 옴
    static func commandLine(profile: String?, status: Int32, errorOutput: String) -> AWSError {
        let detail = errorOutput.nonEmptyLines.last ?? L("aws 가 종료 코드 \(status) 로 끝남", "aws exited with status \(status)")
        if let code = errorOutput.firstMatch(of: /An error occurred \((\w+)\)/).map({ String($0.1) }) {
            return AWSError(profile: profile, kind: kind(forServiceCode: code), detail: detail)
        }
        let lowered = errorOutput.lowercased()
        let kind: Kind = if ["error loading sso token", "token has expired", "sso session associated with this profile has expired"]
            .contains(where: { lowered.contains($0) }) {
            .expiredSession
        } else if lowered.contains("unable to locate credentials")
            || (lowered.contains("config profile") && lowered.contains("could not be found")) {
            .missingCredentials
        } else {
            .other
        }
        return AWSError(profile: profile, kind: kind, detail: detail)
    }

    /// 서명 오류 메시지는 둘째 줄부터 서버가 받은 요청 헤더(세션 토큰 포함)를 되풀이해서 첫 줄만 남김
    static func service(profile: String, code: String, message: String?) -> AWSError {
        let summary = message?.nonEmptyLines.first
        return AWSError(profile: profile, kind: kind(forServiceCode: code), detail: summary.map { "\(code) · \($0)" } ?? code)
    }

    private static func kind(forServiceCode code: String) -> Kind {
        switch code {
        // 키가 바뀌었거나 세션 토큰이 끊긴 경우도 다시 로그인하면 풀림
        case "ExpiredToken", "ExpiredTokenException", "UnrecognizedClientException", "InvalidClientTokenId": .expiredSession
        case "AccessDenied", "AccessDeniedException": .accessDenied
        case "PipelineNotFoundException": .pipelineNotFound
        default: .other
        }
    }

    var errorDescription: String? {
        let profileOption = profile.map { " --profile \($0)" } ?? ""
        return switch kind {
        case .expiredSession: L(
            "인증 만료 · 터미널에서 aws sso login\(profileOption)",
            "Session expired · run aws sso login\(profileOption) in Terminal"
        )
        case .missingCredentials: L(
            "자격 증명 없음 · aws configure list\(profileOption) 로 확인",
            "No credentials · check with aws configure list\(profileOption)"
        )
        case .accessDenied: L("권한 없음 (AccessDenied)", "Access denied")
        case .pipelineNotFound: L("파이프라인이 없음 (이름 · 리전 확인)", "Pipeline not found (check the name and region)")
        case .other: detail
        }
    }
}
