import Foundation
import Testing
@testable import CrowsnestKit

private let ref = PipelineRef(profile: "sample", region: "ap-northeast-1", name: "web-prod")

// 실제 get-pipeline-state 의 승인 액션 모양 그대로, 사람 · 계정만 가짜 값
private let rejectedApproval = #"""
{
    "status": "Failed",
    "summary": "Rejected by arn:aws:sts::example:assumed-role/sample-role/reviewer@example.com",
    "lastUpdatedBy": "arn:aws:sts::example:assumed-role/sample-role/reviewer@example.com"
}
"""#
private let commentedRejection = #"{ "status": "Failed", "summary": "핫픽스 먼저 나감", "lastUpdatedBy": "arn:aws:iam::example:user/reviewer" }"#
private let pendingApproval = #"{ "status": "InProgress", "token": "token-1" }"#
private let failedBuild = #"{ "status": "Failed", "errorDetails": { "message": "Build terminated with state: FAILED" } }"#

/// Build 는 성공했고 두 번째 스테이지의 액션만 바꿔 끼움
private func snapshot(_ status: String, lastAction: String) throws -> PipelineSnapshot {
    let executions = #"{ "pipelineExecutionSummaries": [ { "pipelineExecutionId": "exec-1", "status": "\#(status)" } ] }"#
    let state = #"""
    {
        "stageStates": [
            {
                "stageName": "Build",
                "actionStates": [ { "actionName": "Build", "latestExecution": { "status": "Succeeded" } } ],
                "latestExecution": { "pipelineExecutionId": "exec-1", "status": "Succeeded" }
            },
            {
                "stageName": "Approve",
                "actionStates": [ { "actionName": "Approve", "latestExecution": \#(lastAction) } ],
                "latestExecution": { "pipelineExecutionId": "exec-1", "status": "\#(status)" }
            }
        ]
    }
    """#
    let decoder = JSONDecoder()
    return PipelineSnapshot(
        ref: ref,
        executions: try decoder.decode(ListPipelineExecutionsResponse.self, from: Data(executions.utf8)),
        state: try decoder.decode(GetPipelineStateResponse.self, from: Data(state.utf8))
    )
}

struct PipelineConditionTests {
    @Test func 사람이_반려한_실행은_실패가_아니라_반려로_본다() throws {
        let snapshot = try snapshot("Failed", lastAction: rejectedApproval)

        #expect(snapshot.condition == .rejected(by: "reviewer@example.com", comment: nil))
        #expect(snapshot.stages[1].actions[0].summary == nil)
    }

    @Test func 승인_토큰이_있으면_진행_중이_아니라_승인_대기다() throws {
        let snapshot = try snapshot("InProgress", lastAction: pendingApproval)
        let stage = snapshot.stages[1]

        #expect(snapshot.condition == .awaitingApproval(StageProgress(position: 2, count: 2, stage: stage)))
    }

    @Test func 빌드가_실패하면_그대로_실패다() throws {
        #expect(try snapshot("Failed", lastAction: failedBuild).condition == .finished(.failed))
    }

    @Test func 승인_코멘트는_남긴다() throws {
        let action = try snapshot("Failed", lastAction: commentedRejection).stages[1].actions[0]

        #expect(action.summary == "핫픽스 먼저 나감")
        #expect(action.decidedBy == "reviewer")
    }
}

struct DeployNotificationTests {
    @Test func 앱을_켠_직후_첫_조회에선_안_울린다() throws {
        let snapshot = try snapshot("Failed", lastAction: rejectedApproval)

        #expect(DeployNotification.make(previous: nil, snapshot: snapshot) == nil)
        #expect(DeployNotification.make(previous: .finished(.succeeded), snapshot: snapshot) == nil)
    }

    @Test func 반려는_누가_반려했는지_알린다() throws {
        let snapshot = try snapshot("Failed", lastAction: rejectedApproval)

        #expect(DeployNotification.make(previous: .running(nil), snapshot: snapshot)
            == DeployNotification(title: "web-prod 배포 반려", body: "reviewer@example.com 님이 반려함 · sample"))
    }

    @Test func 승인_대기에_들어갈_때_한_번만_알린다() throws {
        let snapshot = try snapshot("InProgress", lastAction: pendingApproval)

        #expect(DeployNotification.make(previous: .running(nil), snapshot: snapshot)?.title == "web-prod 승인 필요")
        #expect(DeployNotification.make(previous: snapshot.condition, snapshot: snapshot) == nil)
    }

    @Test func 실패는_어느_단계에서_실패했는지_알린다() throws {
        let snapshot = try snapshot("Failed", lastAction: failedBuild)

        #expect(DeployNotification.make(previous: .running(nil), snapshot: snapshot)
            == DeployNotification(title: "web-prod 배포 실패", body: "Approve 단계에서 실패 · sample"))
    }
}
