import Foundation

/// aws CLI 를 자식 프로세스로 돌림 — 각자 맥에 이미 잡혀 있는 프로필 · SSO 세션을 그대로 씀
struct AWSCommandLine: Sendable {
    let executableURL: URL

    /// 메뉴바 앱은 로그인 셸의 PATH 를 못 물려받아서 brew 경로를 직접 봄
    private static let extraSearchPaths = ["/opt/homebrew/bin", "/usr/local/bin"]

    private static let environment: [String: String] = {
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        // credential_process 헬퍼도 brew 경로에 있을 수 있음
        environment["PATH"] = (extraSearchPaths + [inheritedPath]).joined(separator: ":")
        environment["AWS_PAGER"] = ""
        return environment
    }()

    static func locate(preferredPath: String?) -> AWSCommandLine? {
        let candidates = [preferredPath].compactMap { $0 } + (extraSearchPaths + ["/usr/bin"]).map { "\($0)/aws" }
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { AWSCommandLine(executableURL: URL(fileURLWithPath: $0)) }
    }

    /// profile 은 실패했을 때 안내 문구에만 씀
    func run(_ arguments: [String], profile: String? = nil) async throws -> Data {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = Self.environment
        process.standardInput = FileHandle.nullDevice
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()

        // 한쪽만 먼저 읽으면 다른 쪽 파이프 버퍼가 차서 프로세스가 멈출 수 있음
        async let output = Self.readToEnd(outputPipe.fileHandleForReading)
        async let errorOutput = Self.readToEnd(errorPipe.fileHandleForReading)
        let (outputData, errorData) = await (output, errorOutput)
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AWSCommandError(
                profile: profile,
                status: process.terminationStatus,
                errorOutput: String(decoding: errorData, as: UTF8.self)
            )
        }
        return outputData
    }

    /// 블로킹 read 를 협력 스레드 풀 밖으로 뺌
    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}

struct AWSCommandError: LocalizedError, Sendable {
    enum Kind: Equatable, Sendable {
        case expiredSession
        case missingCredentials
        case accessDenied
        case pipelineNotFound
        case other
    }

    let profile: String?
    let status: Int32
    let errorOutput: String

    /// 서비스 에러는 "An error occurred (Code) when calling ..." 로 코드가 오고,
    /// SSO · 자격 증명 에러는 CLI 가 요청 전에 내는 거라 문장으로만 옴
    var kind: Kind {
        switch serviceErrorCode {
        case "ExpiredToken", "ExpiredTokenException": return .expiredSession
        case "AccessDenied", "AccessDeniedException": return .accessDenied
        case "PipelineNotFoundException": return .pipelineNotFound
        case .some: return .other
        case nil: break
        }
        let lowered = errorOutput.lowercased()
        if ["error loading sso token", "token has expired", "sso session associated with this profile has expired"]
            .contains(where: { lowered.contains($0) }) {
            return .expiredSession
        }
        if lowered.contains("unable to locate credentials") || (lowered.contains("config profile") && lowered.contains("could not be found")) {
            return .missingCredentials
        }
        return .other
    }

    var errorDescription: String? {
        let profileOption = profile.map { " --profile \($0)" } ?? ""
        switch kind {
        case .expiredSession: return "인증 만료 · 터미널에서 aws sso login\(profileOption)"
        case .missingCredentials: return "자격 증명 없음 · aws configure list\(profileOption) 로 확인"
        case .accessDenied: return "권한 없음 (AccessDenied)"
        case .pipelineNotFound: return "파이프라인이 없음 (이름 · 리전 확인)"
        case .other: return errorOutput.nonEmptyLines.last ?? "aws 가 종료 코드 \(status) 로 끝남"
        }
    }

    private var serviceErrorCode: String? {
        errorOutput.firstMatch(of: /An error occurred \((\w+)\)/).map { String($0.1) }
    }
}
