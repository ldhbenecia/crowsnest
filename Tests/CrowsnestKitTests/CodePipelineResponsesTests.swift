import Foundation
import Testing
@testable import CrowsnestKit

/// 실제 aws CLI v2 응답 모양 그대로, 계정 · 연결 정보만 가짜 값으로 바꿈
private let executionsJSON = #"""
{
    "pipelineExecutionSummaries": [
        {
            "pipelineExecutionId": "exec-2",
            "status": "InProgress",
            "startTime": "2026-10-20T15:06:54.437000+09:00",
            "lastUpdateTime": "2026-10-20T15:14:20.919000+09:00",
            "sourceRevisions": [
                {
                    "actionName": "Source",
                    "revisionId": "0d576bf6d187d9b34017b63b01787ad2457a3420",
                    "revisionSummary": "{\"ProviderType\":\"GitHub\",\"CommitMessage\":\"deploy: 알림 수정\\n\\n본문\"}"
                }
            ],
            "executionMode": "SUPERSEDED"
        }
    ],
    "NextToken": "token"
}
"""#

private let stateJSON = #"""
{
    "pipelineName": "sample-api-test",
    "stageStates": [
        {
            "stageName": "Source",
            "actionStates": [
                {
                    "actionName": "Source",
                    "latestExecution": { "status": "Succeeded", "summary": "{\"ProviderType\":\"GitHub\",\"CommitMessage\":\"deploy: 알림 수정\"}" }
                }
            ],
            "latestExecution": { "pipelineExecutionId": "exec-2", "status": "Succeeded" }
        },
        {
            "stageName": "Build",
            "actionStates": [
                {
                    "actionName": "Build-webserver",
                    "latestExecution": {
                        "status": "InProgress",
                        "externalExecutionUrl": "https://console.aws.amazon.com/codebuild/home?region=ap-northeast-1#/builds/sample:1/view/new"
                    }
                },
                {
                    "actionName": "Build-worker",
                    "latestExecution": {
                        "status": "Failed",
                        "errorDetails": { "code": "JobFailed", "message": "Build terminated with state: FAILED" }
                    }
                }
            ],
            "latestExecution": { "pipelineExecutionId": "exec-2", "status": "InProgress" }
        },
        {
            "stageName": "Deploy",
            "actionStates": [
                { "actionName": "Deploy-webserver", "latestExecution": { "status": "Succeeded" } }
            ],
            "latestExecution": { "pipelineExecutionId": "exec-1", "status": "Succeeded" }
        },
        {
            "stageName": "Approve",
            "actionStates": [ { "actionName": "Manual" } ]
        },
        {
            "stageName": "Release",
            "actionStates": [ { "actionName": "Release", "latestExecution": { "status": "InProgress" } } ],
            "latestExecution": { "pipelineExecutionId": "exec-1", "status": "InProgress" }
        }
    ]
}
"""#

private let ref = PipelineRef(profile: "sample", region: "ap-northeast-1", name: "sample-api-test")

private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date? {
    DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(identifier: "UTC"),
        year: year, month: month, day: day, hour: hour, minute: minute, second: second
    ).date
}

private func makeSnapshot() throws -> PipelineSnapshot {
    let decoder = JSONDecoder()
    return PipelineSnapshot(
        ref: ref,
        executions: try decoder.decode(ListPipelineExecutionsResponse.self, from: Data(executionsJSON.utf8)),
        state: try decoder.decode(GetPipelineStateResponse.self, from: Data(stateJSON.utf8))
    )
}

struct CodePipelineResponsesTests {
    @Test func 실행_요약과_스테이지를_합친다() throws {
        let snapshot = try makeSnapshot()

        #expect(snapshot.execution?.id == "exec-2")
        #expect(snapshot.execution?.status == .inProgress)
        #expect(snapshot.stages.map(\.name) == ["Source", "Build", "Deploy", "Approve", "Release"])
        #expect(snapshot.runningStage?.position == 2)
        #expect(snapshot.runningStage?.stage.name == "Build")
    }

    @Test func 커밋_메시지는_CodeStar_JSON_에서_첫_줄만_꺼낸다() throws {
        let revision = try #require(try makeSnapshot().execution?.revision)

        #expect(revision.shortId == "0d576bf")
        #expect(revision.message == "deploy: 알림 수정")
    }

    @Test func 끝난_지난_실행이_남은_스테이지를_구분한다() throws {
        let stages = try makeSnapshot().stages

        #expect(stages.map(\.isCurrent) == [true, true, false, false, true])
        #expect(stages[3].status == nil)
    }

    @Test func 액션의_실패_사유와_로그_링크를_꺼낸다() throws {
        let actions = try makeSnapshot().stages[1].actions

        #expect(actions[0].externalURL?.host() == "console.aws.amazon.com")
        #expect(actions[1].status == .failed)
        #expect(actions[1].errorMessage == "Build terminated with state: FAILED")
    }

    @Test func 로그_링크는_웹_주소만_받는다() {
        #expect(PipelineSnapshot.webURL("https://example.com/build") != nil)
        #expect(PipelineSnapshot.webURL("file:///Applications/Calculator.app") == nil)
        #expect(PipelineSnapshot.webURL("x-apple.systempreferences:com.apple.preference") == nil)
    }

    @Test func 마이크로초와_오프셋이_붙은_시각을_읽는다() throws {
        let date = try #require(AWSTimestamp.parse("2026-10-20T15:06:54.437000+09:00"))
        let wholeSecond = try #require(utcDate(2026, 10, 20, 6, 6, 54))

        #expect(abs(date.timeIntervalSince(wholeSecond) - 0.437) < 0.001)
    }

    @Test func 소수점이_없는_시각도_읽는다() throws {
        let date = try #require(AWSTimestamp.parse("2026-10-20T06:06:54Z"))

        #expect(date == utcDate(2026, 10, 20, 6, 6, 54))
    }

    @Test func 모르는_상태값은_원문을_보존한다() throws {
        let status = try JSONDecoder().decode(PipelineStatus.self, from: Data(#""Paused""#.utf8))

        #expect(status == .unknown("Paused"))
        #expect(status.label == "Paused")
    }

    @Test func 만료된_SSO_토큰은_로그인_명령을_안내한다() {
        let error = AWSCommandError(
            profile: "sample",
            status: 255,
            errorOutput: "\nError when retrieving token from sso: Token has expired and refresh failed\n"
        )

        #expect(error.errorDescription == "인증 만료 · 터미널에서 aws sso login --profile sample")
    }

    @Test func 서비스_에러_코드를_문장보다_먼저_본다() {
        let error = AWSCommandError(
            profile: "sample",
            status: 254,
            errorOutput: "\nAn error occurred (AccessDeniedException) when calling the GetPipelineState operation: User is not authorized to perform: codepipeline:GetPipelineState\n"
        )

        #expect(error.kind == .accessDenied)
    }

    @Test func 모르는_에러는_마지막_줄을_그대로_보여준다() {
        let error = AWSCommandError(profile: nil, status: 1, errorOutput: "first line\n  something broke  \n\n")

        #expect(error.kind == .other)
        #expect(error.errorDescription == "something broke")
    }
}
