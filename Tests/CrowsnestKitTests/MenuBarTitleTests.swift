import Testing
@testable import CrowsnestKit

private func snapshot(_ name: String, execution: PipelineStatus?, stages: [PipelineStatus?] = [], failureReason: String? = nil) -> PipelineSnapshot {
    PipelineSnapshot(
        ref: PipelineRef(profile: "sample", region: "ap-northeast-1", name: name),
        execution: execution.map { ExecutionSummary(id: "exec", status: $0, startedAt: nil, updatedAt: nil, revision: nil) },
        stages: stages.enumerated().map { index, status in
            StageSnapshot(name: "Stage\(index + 1)", status: status, isFromLatestExecution: true, actions: [])
        },
        failureReason: failureReason
    )
}

struct MenuBarTitleTests {
    @Test func 고른_게_없으면_아이콘만_띄운다() {
        #expect(MenuBarTitle.make(for: []) == nil)
    }

    @Test func 첫_진행_중_파이프라인과_나머지_개수를_보여준다() {
        let title = MenuBarTitle.make(for: [
            snapshot("batch-prod", execution: .succeeded, stages: [.succeeded]),
            snapshot("web-prod", execution: .inProgress, stages: [.succeeded, .inProgress, nil]),
            snapshot("worker-prod", execution: .inProgress, stages: [.inProgress, nil]),
        ])

        #expect(title == "🔵 web-prod: Stage2 2/3 ⋯+1")
    }

    @Test func 긴_이름은_구분되는_끝을_살려서_자른다() {
        let long = PipelineSnapshot(
            ref: PipelineRef(profile: "sample", region: "ap-northeast-1", name: "sample-service-admin-console-production"),
            execution: ExecutionSummary(id: "exec", status: .inProgress, startedAt: nil, updatedAt: nil, revision: nil),
            stages: [StageSnapshot(name: "IntegrationTestsAndSmoke", status: .inProgress, isFromLatestExecution: true, actions: [])],
            failureReason: nil
        )

        #expect(MenuBarTitle.make(for: [long]) == "🔵 sample-servi…-production: Integration… 1/1")
    }

    @Test func 한도_안이면_그대로_둔다() {
        #expect("web-prod".truncated(to: 8, keepingTail: 3) == "web-prod")
        #expect("Deploy".truncated(to: 6) == "Deploy")
        #expect("abcdefghi".truncated(to: 8, keepingTail: 3) == "abcd…ghi")
    }

    @Test func 쉬는_중이면_실패를_성공보다_먼저_알린다() {
        let title = MenuBarTitle.make(for: [
            snapshot("web-prod", execution: .succeeded),
            snapshot("worker-prod", execution: .failed),
        ])

        #expect(title == "🔴")
    }

    @Test func 조회_실패가_있으면_성공_대신_경고를_띄운다() {
        let title = MenuBarTitle.make(for: [
            snapshot("web-prod", execution: .succeeded),
            snapshot("worker-prod", execution: nil, failureReason: "인증 만료"),
        ])

        #expect(title == "⚠️")
    }
}
