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

    /// 소수점 6자리(마이크로초)는 ISO8601DateFormatter 가 못 읽어서 초 단위로 잘라냄
    static func parse(_ text: String) -> Date? {
        let withoutFraction = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: withoutFraction)
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
                isFromLatestExecution: execution == nil || stage.latestExecution?.pipelineExecutionId == execution?.id,
                actions: (stage.actionStates ?? []).map { action in
                    ActionSnapshot(
                        name: action.actionName,
                        status: action.latestExecution?.status,
                        summary: SourceRevision.commitMessage(from: action.latestExecution?.summary),
                        errorMessage: action.latestExecution?.errorDetails?.message,
                        externalURL: action.latestExecution?.externalExecutionUrl.flatMap(URL.init(string:))
                    )
                }
            )
        }
        self.init(ref: ref, execution: execution, stages: stages, failureReason: nil)
    }
}

extension SourceRevision {
    init(wire: ListPipelineExecutionsResponse.Summary.Revision) {
        // ECR 소스는 sha256:... 형태라 콜론 뒤만 씀
        shortId = wire.revisionId.map { revisionId in
            String((revisionId.split(separator: ":").last ?? Substring(revisionId)).prefix(7))
        }
        message = Self.commitMessage(from: wire.revisionSummary)
    }

    /// GitHub(CodeStar 연결) 소스는 요약 자리에 {"ProviderType":..,"CommitMessage":..} JSON 을 넣어줌
    static func commitMessage(from summary: String?) -> String? {
        guard let summary, !summary.isEmpty else { return nil }
        let codeStar = try? JSONDecoder().decode(CodeStarRevisionSummary.self, from: Data(summary.utf8))
        let message = codeStar?.commitMessage ?? summary
        return message.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private struct CodeStarRevisionSummary: Decodable {
    let commitMessage: String

    enum CodingKeys: String, CodingKey {
        case commitMessage = "CommitMessage"
    }
}
