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
        // 급할 것 없는 백그라운드 조회라 효율 코어로 보냄
        process.qualityOfService = .utility
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
            throw AWSError.commandLine(
                profile: profile,
                status: process.terminationStatus,
                errorOutput: String(decoding: errorData, as: UTF8.self)
            )
        }
        return outputData
    }

    /// 값이 없으면 aws configure get 이 종료 코드 1 로 끝나서 nil
    func configValue(_ key: String, profile: String) async -> String? {
        let output = try? await run(["configure", "get", key, "--profile", profile])
        return output.flatMap { String(decoding: $0, as: UTF8.self).nonEmptyLines.first }
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
