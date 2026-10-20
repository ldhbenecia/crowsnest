import Testing
@testable import CrowsnestKit

private func snapshot(
    _ name: String,
    execution: PipelineStatus?,
    stages: [PipelineStatus?] = [],
    failureReason: String? = nil
) -> PipelineSnapshot {
    PipelineSnapshot(
        ref: PipelineRef(profile: "sample", region: "ap-northeast-1", name: name),
        execution: execution.map { ExecutionSummary(id: "exec", status: $0, startedAt: nil, updatedAt: nil, revision: nil) },
        stages: stages.enumerated().map { index, status in
            StageSnapshot(name: "Stage\(index + 1)", status: status, belongsToLatestExecution: true, actions: [])
        },
        failureReason: failureReason
    )
}

private func awaitingApproval(_ name: String) -> PipelineSnapshot {
    let approval = ActionSnapshot(
        name: "Approve", status: .inProgress, summary: nil, errorMessage: nil, externalURL: nil,
        decidedBy: nil, isAwaitingApproval: true
    )
    return PipelineSnapshot(
        ref: PipelineRef(profile: "sample", region: "ap-northeast-1", name: name),
        execution: ExecutionSummary(id: "exec", status: .inProgress, startedAt: nil, updatedAt: nil, revision: nil),
        stages: [
            StageSnapshot(name: "Build", status: .succeeded, belongsToLatestExecution: true, actions: []),
            StageSnapshot(name: "Approve", status: .inProgress, belongsToLatestExecution: true, actions: [approval]),
        ],
        failureReason: nil
    )
}

struct MenuBarStatusTests {
    @Test func 고른_게_없으면_글리프만_띄운다() {
        #expect(MenuBarStatus.make(for: []) == .idle)
    }

    @Test func 첫_진행_중_파이프라인과_나머지_개수를_보여준다() {
        let status = MenuBarStatus.make(for: [
            snapshot("batch-prod", execution: .succeeded, stages: [.succeeded]),
            snapshot("web-prod", execution: .inProgress, stages: [.succeeded, .inProgress, nil]),
            snapshot("worker-prod", execution: .inProgress, stages: [.inProgress, nil]),
        ])

        #expect(status == .active(.init(
            name: "web-prod", progress: .init(position: 2, count: 3), isAwaitingApproval: false, othersCount: 1
        )))
    }

    @Test func 승인_대기를_진행_중보다_먼저_보여준다() {
        let status = MenuBarStatus.make(for: [
            snapshot("worker-prod", execution: .inProgress, stages: [.inProgress]),
            awaitingApproval("web-prod"),
        ])

        #expect(status == .active(.init(
            name: "web-prod", progress: .init(position: 2, count: 2), isAwaitingApproval: true, othersCount: 1
        )))
    }

    @Test func 긴_이름은_구분되는_끝을_살려서_자른다() {
        let status = MenuBarStatus.make(for: [
            snapshot("sample-service-admin-console-production", execution: .inProgress, stages: [.inProgress]),
        ])

        guard case .active(let pipeline) = status else {
            Issue.record("진행 중이 아님 · \(status)")
            return
        }
        #expect(pipeline.name == "sample-servi…-production")
    }

    @Test func 한도_안이면_그대로_둔다() {
        #expect("web-prod".truncated(to: 8, keepingTail: 3) == "web-prod")
        #expect("Deploy".truncated(to: 6) == "Deploy")
        #expect("abcdefghi".truncated(to: 8, keepingTail: 3) == "abcd…ghi")
    }

    @Test func 쉬는_중에_실패나_조회_실패가_있으면_점을_찍는다() {
        #expect(MenuBarStatus.make(for: [
            snapshot("web-prod", execution: .succeeded),
            snapshot("worker-prod", execution: .failed),
        ]) == .needsAttention)
        #expect(MenuBarStatus.make(for: [
            snapshot("web-prod", execution: .succeeded),
            snapshot("worker-prod", execution: nil, failureReason: "인증 만료"),
        ]) == .needsAttention)
    }

    @Test func 전부_성공이면_글리프만_띄운다() {
        #expect(MenuBarStatus.make(for: [snapshot("web-prod", execution: .succeeded)]) == .idle)
    }
}
