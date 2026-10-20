import Foundation

/// 파이프라인 하나를 가리키는 좌표 — 선택 목록에 그대로 저장됨
struct PipelineRef: Hashable, Codable, Identifiable, Sendable {
    let profile: String
    let region: String
    let name: String

    var id: String { "\(profile)|\(region)|\(name)" }

    var consoleURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(region).console.aws.amazon.com"
        components.path = "/codesuite/codepipeline/pipelines/\(name)/view"
        components.queryItems = [URLQueryItem(name: "region", value: region)]
        return components.url ?? URL(string: "https://console.aws.amazon.com/codesuite/codepipeline/pipelines")!
    }
}

struct SourceRevision: Sendable, Equatable {
    let shortId: String?
    let message: String?
}

struct ExecutionSummary: Sendable, Equatable {
    let id: String
    let status: PipelineStatus
    let startedAt: Date?
    let updatedAt: Date?
    let revision: SourceRevision?
}

struct ActionSnapshot: Identifiable, Sendable, Equatable {
    let name: String
    let status: PipelineStatus?
    let summary: String?
    let errorMessage: String?
    let externalURL: URL?

    var id: String { name }
}

struct StageSnapshot: Identifiable, Sendable, Equatable {
    let name: String
    let status: PipelineStatus?
    /// false 면 지난 실행 결과가 남아 있는 것 — 콘솔은 구분 없이 보여줘서 헷갈림
    let isFromLatestExecution: Bool
    let actions: [ActionSnapshot]

    var id: String { name }
}

struct PipelineSnapshot: Sendable, Equatable {
    let ref: PipelineRef
    let execution: ExecutionSummary?
    let stages: [StageSnapshot]
    /// 조회 자체가 실패했을 때 (인증 만료 등)
    let failureReason: String?

    static func failed(_ ref: PipelineRef, reason: String) -> PipelineSnapshot {
        PipelineSnapshot(ref: ref, execution: nil, stages: [], failureReason: reason)
    }

    /// 지금 돌고 있는 스테이지와 몇 번째인지 (1부터)
    var runningStage: (position: Int, stage: StageSnapshot)? {
        guard let index = stages.firstIndex(where: { $0.status == .inProgress }) else { return nil }
        return (index + 1, stages[index])
    }
}
