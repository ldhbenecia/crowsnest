import Foundation
import Testing
@testable import CrowsnestKit

struct CommandLineTests {
    @Test func 취소하면_기다리던_프로세스를_끝낸다() async throws {
        let cli = AWSCommandLine(executableURL: URL(fileURLWithPath: "/bin/sleep"))
        let started = Date.now

        let task = Task { try await cli.run(["30"], terminatesOnCancel: true) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        await #expect(throws: AWSError.self) { try await task.value }
        #expect(Date.now.timeIntervalSince(started) < 5)
    }
}
