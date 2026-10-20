import Foundation

// aws codepipeline ... --output json 응답 중 쓰는 필드만

struct ListPipelinesResponse: Decodable, Sendable {
    struct Pipeline: Decodable, Sendable {
        let name: String
    }

    let pipelines: [Pipeline]
}

struct ListPipelineExecutionsResponse: Decodable, Sendable {
    struct Summary: Decodable, Sendable {
        struct Revision: Decodable, Sendable {
            let revisionId: String?
            let revisionSummary: String?
        }

        let pipelineExecutionId: String
        let status: PipelineStatus
        let startTime: AWSTimestamp?
        let lastUpdateTime: AWSTimestamp?
        let sourceRevisions: [Revision]?
    }

    let pipelineExecutionSummaries: [Summary]
}

struct GetPipelineStateResponse: Decodable, Sendable {
    struct StageState: Decodable, Sendable {
        struct LatestExecution: Decodable, Sendable {
            let pipelineExecutionId: String?
            let status: PipelineStatus?
        }

        let stageName: String
        let latestExecution: LatestExecution?
        let actionStates: [ActionState]?
    }

    struct ActionState: Decodable, Sendable {
        struct LatestExecution: Decodable, Sendable {
            struct ErrorDetails: Decodable, Sendable {
                let message: String?
            }

            let status: PipelineStatus?
            let summary: String?
            let errorDetails: ErrorDetails?
            let externalExecutionUrl: String?
            let lastUpdatedBy: String?
            let token: String?
        }

        let actionName: String
        let latestExecution: LatestExecution?
    }

    let stageStates: [StageState]?
}

/// AWS CLI 는 cli_timestamp_format 설정에 따라 ISO8601 문자열이나 epoch 숫자를 줌
struct AWSTimestamp: Decodable, Sendable, Equatable {
    let date: Date

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let seconds = try? container.decode(Double.self) {
            date = Date(timeIntervalSince1970: seconds)
            return
        }
        let text = try container.decode(String.self)
        guard let parsed = Self.parse(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "시각 형식을 못 읽음: \(text)")
        }
        date = parsed
    }

    /// CLI 는 소수점 6자리(마이크로초)까지 붙여서 주고, 설정에 따라 소수점이 없을 때도 있음
    static func parse(_ text: String) -> Date? {
        (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(text, strategy: .iso8601))
    }
}

extension PipelineSnapshot {
    init(ref: PipelineRef, executions: ListPipelineExecutionsResponse, state: GetPipelineStateResponse) {
        let execution = executions.pipelineExecutionSummaries.first.map { summary in
            ExecutionSummary(
                id: summary.pipelineExecutionId,
                status: summary.status,
                startedAt: summary.startTime?.date,
                updatedAt: summary.lastUpdateTime?.date,
                revision: summary.sourceRevisions?.first.map(SourceRevision.init(wire:))
            )
        }
        let stages = (state.stageStates ?? []).map { stage in
            StageSnapshot(
                name: stage.stageName,
                status: stage.latestExecution?.status,
                belongsToLatestExecution: execution == nil || stage.latestExecution?.pipelineExecutionId == execution?.id,
                actions: (stage.actionStates ?? []).map { action in
                    let latest = action.latestExecution
                    let summary = Self.droppingApprovalBoilerplate(latest?.summary)
                    return ActionSnapshot(
                        name: action.actionName,
                        status: latest?.status,
                        summary: SourceRevision.codeStarCommitMessage(summary) ?? summary,
                        errorMessage: latest?.errorDetails?.message,
                        externalURL: latest?.externalExecutionUrl.flatMap(Self.webURL),
                        // 실제 응답에선 수동 승인 액션에만 lastUpdatedBy 가 붙음
                        decidedBy: latest?.lastUpdatedBy.map(Self.principalName),
                        isAwaitingApproval: latest?.status == .inProgress && latest?.token != nil
                    )
                }
            )
        }
        self.init(ref: ref, execution: execution, stages: stages, failureReason: nil)
    }

    /// 코멘트 없이 승인 · 반려하면 요약이 "Approved by <ARN>" 이라 버림
    private static func droppingApprovalBoilerplate(_ summary: String?) -> String? {
        guard let summary, !summary.hasPrefix("Approved by "), !summary.hasPrefix("Rejected by ") else { return nil }
        return summary
    }

    /// assumed-role ARN 은 끝이 세션 이름(보통 SSO 사용자), IAM 사용자 ARN 은 끝이 사용자 이름
    static func principalName(_ arn: String) -> String {
        arn.split(separator: "/").last.map(String.init) ?? arn
    }

    /// 커스텀 액션은 아무 URL 이나 넣을 수 있어서 다른 앱을 띄우는 스킴은 버림
    static func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased()) else { return nil }
        return url
    }
}

extension SourceRevision {
    init(wire: ListPipelineExecutionsResponse.Summary.Revision) {
        // ECR 소스는 sha256:... 형태라 콜론 뒤만 씀
        shortId = wire.revisionId.map { revisionId in
            String((revisionId.split(separator: ":").last ?? Substring(revisionId)).prefix(7))
        }
        message = Self.codeStarCommitMessage(wire.revisionSummary) ?? wire.revisionSummary?.nonEmptyLines.first
    }

    /// GitHub(CodeStar 연결) 소스는 요약 자리에 {"ProviderType":..,"CommitMessage":..} JSON 을 넣어줌 — 다른 소스면 nil
    static func codeStarCommitMessage(_ summary: String?) -> String? {
        guard let summary, let decoded = try? JSONDecoder().decode(CodeStarRevisionSummary.self, from: Data(summary.utf8)) else {
            return nil
        }
        return decoded.commitMessage.nonEmptyLines.first
    }
}

private struct CodeStarRevisionSummary: Decodable {
    let commitMessage: String

    enum CodingKeys: String, CodingKey {
        case commitMessage = "CommitMessage"
    }
}
