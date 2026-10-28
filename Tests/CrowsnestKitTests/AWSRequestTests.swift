import Foundation
import Testing
@testable import CrowsnestKit

struct AWSRequestTests {
    init() {
        // 문구 비교라 CI 러너(영어) 에서도 한국어로 고정
        Localization.apply(.korean)
    }

    /// AWS Signature Version 4 공식 테스트 묶음의 get-vanilla — 키 · 시각 · 서명 모두 문서에 실린 예제 값
    @Test func 공식_테스트_벡터와_같은_서명을_만든다() throws {
        let signer = SignatureV4(
            credentials: AWSCredentials(
                accessKeyId: "AKIDEXAMPLE",
                secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
                sessionToken: nil,
                expiration: nil
            ),
            region: "us-east-1",
            service: "service"
        )
        let date = try #require(AWSTimestamp.parse("2015-08-30T12:36:00Z"))

        let headers = signer.signedHeaders(
            method: "GET",
            url: try #require(URL(string: "https://example.amazonaws.com/")),
            headers: [:],
            body: Data(),
            date: date
        )

        #expect(headers["authorization"] == "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, "
            + "SignedHeaders=host;x-amz-date, Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31")
        #expect(headers["x-amz-date"] == "20150830T123600Z")
    }

    @Test func 임시_자격_증명은_세션_토큰을_서명에_넣는다() throws {
        let signer = SignatureV4(
            credentials: AWSCredentials(accessKeyId: "AKID", secretAccessKey: "secret", sessionToken: "token", expiration: nil),
            region: "ap-northeast-1",
            service: "codepipeline"
        )

        let headers = signer.signedHeaders(
            method: "POST",
            url: try #require(URL(string: "https://codepipeline.ap-northeast-1.amazonaws.com/")),
            headers: ["x-amz-target": "CodePipeline_20150709.GetPipelineState"],
            body: Data("{}".utf8),
            date: .now
        )

        #expect(headers["x-amz-security-token"] == "token")
        #expect(headers["authorization"]?.contains("SignedHeaders=host;x-amz-date;x-amz-security-token;x-amz-target") == true)
    }

    @Test func export_credentials_출력을_읽고_키는_설명에_안_찍힌다() throws {
        let output = #"{"Version": 1, "AccessKeyId": "AKID", "SecretAccessKey": "secret", "SessionToken": "token", "Expiration": "2026-10-21T09:00:00+00:00"}"#

        let credentials = try JSONDecoder().decode(AWSCredentials.self, from: Data(output.utf8))

        #expect(credentials.sessionToken == "token")
        #expect(credentials.expiration == AWSTimestamp.parse("2026-10-21T09:00:00Z"))
        #expect(!"\(credentials)".contains("secret"))
    }

    @Test func API_에러_코드로_안내_문구를_고른다() {
        #expect(AWSError.service(profile: "sample", code: "ExpiredTokenException", message: "expired").kind == .expiredSession)
        #expect(AWSError.service(profile: "sample", code: "PipelineNotFoundException", message: nil).kind == .pipelineNotFound)
        #expect(AWSError.service(profile: "sample", code: "ThrottlingException", message: "Rate exceeded").errorDescription
            == "ThrottlingException · Rate exceeded")
    }

    @Test func 서명_오류가_되풀이하는_요청_헤더는_버린다() {
        let message = "The request signature we calculated does not match.\n\nThe Canonical String for this request should have been\n'POST\n/\n\nx-amz-security-token:secret-token\n'"

        let error = AWSError.service(profile: "sample", code: "InvalidSignatureException", message: message)

        #expect(error.errorDescription?.contains("secret-token") == false)
    }
}

struct StageChangeTests {
    private func snapshot(_ stages: [(String, String?, PipelineStatus?)], execution: PipelineStatus = .inProgress) -> PipelineSnapshot {
        PipelineSnapshot(
            ref: PipelineRef(profile: "sample", region: "ap-northeast-1", name: "web-prod"),
            execution: ExecutionSummary(id: "exec-1", status: execution, startedAt: nil, updatedAt: nil, revision: nil),
            stages: stages.map { StageSnapshot(name: $0.0, status: $0.2, executionId: $0.1, belongsToLatestExecution: true, actions: []) },
            failureReason: nil
        )
    }

    @Test func 스테이지_실행과_상태가_같으면_실행_요약을_다시_안_받는다() {
        let previous = snapshot([("Build", "exec-1", .inProgress), ("Deploy", "exec-0", .succeeded)])

        #expect(previous.hasSameStageProgress(as: snapshot([("Build", "exec-1", .inProgress), ("Deploy", "exec-0", .succeeded)])))
        #expect(!previous.hasSameStageProgress(as: snapshot([("Build", "exec-1", .succeeded), ("Deploy", "exec-0", .succeeded)])))
        #expect(!previous.hasSameStageProgress(as: snapshot([("Build", "exec-2", .inProgress), ("Deploy", "exec-0", .succeeded)])))
    }

    @Test func 스테이지가_다_끝났어도_실행이_진행_중으로_남아_있으면_다시_받는다() {
        // 마지막 스테이지가 끝난 직후 받은 실행 요약은 아직 InProgress 일 수 있음
        let finishedStages = [("Build", "exec-1", PipelineStatus.succeeded), ("Deploy", "exec-1", .succeeded)]
        let caughtMidway = snapshot(finishedStages, execution: .inProgress)
        let settled = snapshot(finishedStages, execution: .succeeded)

        #expect(!snapshot(finishedStages).canReuseExecution(of: caughtMidway))
        #expect(snapshot(finishedStages).canReuseExecution(of: settled))
    }
}
