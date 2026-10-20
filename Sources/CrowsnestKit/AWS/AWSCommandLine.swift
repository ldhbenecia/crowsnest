import Foundation

/// aws CLI 를 자식 프로세스로 돌림 — 각자 맥에 이미 잡혀 있는 프로필 · SSO 세션을 그대로 씀
struct AWSCommandLine: Sendable {
    let executableURL: URL

    static func locate(preferredPath: String?) -> AWSCommandLine? {
        let candidates = [preferredPath, "/opt/homebrew/bin/aws", "/usr/local/bin/aws", "/usr/bin/aws"].compactMap { $0 }
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { AWSCommandLine(executableURL: URL(fileURLWithPath: $0)) }
    }

    func run(_ arguments: [String]) async throws -> Data {
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
                profile: arguments.firstIndex(of: "--profile").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil },
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

    /// 메뉴바 앱은 로그인 셸의 PATH 를 못 물려받음 — credential_process 헬퍼가 brew 경로에 있을 수 있음
    private static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(inheritedPath)"
        environment["AWS_PAGER"] = ""
        return environment
    }
}

struct AWSCommandError: LocalizedError, Sendable {
    let profile: String?
    let status: Int32
    let errorOutput: String

    var errorDescription: String? {
        let lowered = errorOutput.lowercased()
        let profileOption = profile.map { " --profile \($0)" } ?? ""
        let expiredMarkers = ["token has expired", "expiredtoken", "error loading sso token", "sso session", "refresh failed"]
        if expiredMarkers.contains(where: { lowered.contains($0) }) {
            return "인증 만료 · 터미널에서 aws sso login\(profileOption)"
        }
        if lowered.contains("unable to locate credentials") || lowered.contains("could not be found") {
            return "자격 증명 없음 · aws configure list\(profileOption) 로 확인"
        }
        if lowered.contains("accessdenied") || lowered.contains("not authorized") {
            return "권한 없음 (AccessDenied)"
        }
        if lowered.contains("pipelinenotfound") {
            return "파이프라인이 없음 (이름 · 리전 확인)"
        }
        let lastLine = errorOutput
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
        return lastLine ?? "aws 가 종료 코드 \(status) 로 끝남"
    }
}
