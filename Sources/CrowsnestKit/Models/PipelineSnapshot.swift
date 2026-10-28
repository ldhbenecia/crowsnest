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
    /// 수동 승인을 누른 사람 — 승인 액션에만 붙음
    let decidedBy: String?
    /// 승인 대기 중인 수동 승인 액션에만 토큰이 붙음
    let isAwaitingApproval: Bool

    var id: String { name }

    /// 사람이 반려한 건 실패가 아니라 일부러 멈춘 것 — 빌드 실패처럼 에러가 붙은 건 반려가 아님
    var isRejected: Bool { status == .failed && decidedBy != nil && errorMessage == nil }
}

struct StageSnapshot: Identifiable, Sendable, Equatable {
    let name: String
    let status: PipelineStatus?
    /// 이 스테이지가 마지막으로 돈 실행
    let executionId: String?
    let belongsToLatestExecution: Bool
    let actions: [ActionSnapshot]

    var id: String { name }

    /// false 면 끝난 지난 실행 결과가 남아 있는 것 — 콘솔은 구분 없이 보여줘서 헷갈림
    /// PARALLEL 모드나 SUPERSEDED 대기 중엔 예전 실행이 아직 돌고 있을 수 있어서 진행 중이면 현재로 봄
    var isCurrent: Bool { belongsToLatestExecution || status == .inProgress }

    /// 승인 말고 돌고 있는 액션이 없을 때만 — 승인이랑 빌드가 같이 돌면 진행 중으로 봄
    var isAwaitingApproval: Bool {
        let running = actions.filter { $0.status == .inProgress }
        return !running.isEmpty && running.allSatisfy(\.isAwaitingApproval)
    }
}

struct StageProgress: Sendable, Equatable {
    /// 1부터
    let position: Int
    let count: Int
    let stage: StageSnapshot
}

/// 화면 · 알림이 보는 파이프라인 상태 — 실행 상태만으론 승인 대기와 반려를 구분 못 함
enum PipelineCondition: Sendable, Equatable {
    case unavailable(reason: String)
    case neverRun
    /// 스테이지 사이를 넘어가는 순간엔 돌고 있는 스테이지가 없음
    case running(StageProgress?)
    case awaitingApproval(StageProgress)
    case rejected(by: String?, comment: String?)
    case finished(PipelineStatus)

    var isActive: Bool {
        switch self {
        case .running, .awaitingApproval: true
        case .unavailable, .neverRun, .rejected, .finished: false
        }
    }

    var progress: StageProgress? {
        switch self {
        case .running(let progress): progress
        case .awaitingApproval(let progress): progress
        case .unavailable, .neverRun, .rejected, .finished: nil
        }
    }

    /// 실패 · 조회 실패 — 반려는 일부러 멈춘 거라 뺌
    var needsAttention: Bool {
        switch self {
        case .unavailable, .finished(.failed): true
        default: false
        }
    }

    var isAwaitingApproval: Bool {
        if case .awaitingApproval = self { true } else { false }
    }

    var isUnavailable: Bool {
        if case .unavailable = self { true } else { false }
    }

    var label: String {
        switch self {
        case .unavailable: L("조회 실패", "Unavailable")
        case .neverRun: L("실행 기록 없음", "Never run")
        case .running: L("진행 중", "In progress")
        case .awaitingApproval: L("승인 대기", "Awaiting approval")
        case .rejected: L("반려됨", "Rejected")
        case .finished(let status): status.label
        }
    }
}

struct PipelineSnapshot: Sendable, Equatable {
    let ref: PipelineRef
    let execution: ExecutionSummary?
    let stages: [StageSnapshot]
    /// 조회 자체가 실패했을 때 (인증 만료 등)
    let failureReason: String?
    /// AWS 가 알려준 실패 종류 — 네트워크 오류처럼 AWS 밖에서 난 실패면 nil
    var failureKind: AWSError.Kind?

    /// 다시 로그인하면 풀리는 실패 — 패널에 로그인 버튼을 띄움
    var needsSignIn: Bool { failureKind == .expiredSession }

    static func failed(_ ref: PipelineRef, error: any Error) -> PipelineSnapshot {
        PipelineSnapshot(ref: ref, execution: nil, stages: [], failureReason: error.localizedDescription, failureKind: (error as? AWSError)?.kind)
    }

    /// 스테이지마다 어느 실행이 어떤 상태인지가 같으면 실행 요약도 그대로임 — 실행 목록 조회를 건너뛰는 데 씀
    func hasSameStageProgress(as other: PipelineSnapshot) -> Bool {
        stages.elementsEqual(other.stages) {
            $0.name == $1.name && $0.executionId == $1.executionId && $0.status == $1.status
        }
    }

    /// 직전 실행 요약을 다시 받지 않고 써도 되는지
    /// 마지막 스테이지가 끝난 직후엔 실행 상태가 잠깐 InProgress 로 남음 — 그걸 그대로 붙잡으면 다 끝났는데도 계속 진행 중으로 보여서, 안 끝난 실행은 매번 다시 받음
    func canReuseExecution(of previous: PipelineSnapshot) -> Bool {
        guard let status = previous.execution?.status, status != .inProgress, status != .stopping else { return false }
        return hasSameStageProgress(as: previous)
    }

    var runningStage: StageProgress? {
        guard let index = stages.firstIndex(where: { $0.status == .inProgress }) else { return nil }
        return StageProgress(position: index + 1, count: stages.count, stage: stages[index])
    }

    var condition: PipelineCondition {
        if let failureReason { return .unavailable(reason: failureReason) }
        if let progress = runningStage {
            return progress.stage.isAwaitingApproval ? .awaitingApproval(progress) : .running(progress)
        }
        guard let execution else { return .neverRun }
        switch execution.status {
        case .inProgress:
            return .running(nil)
        case .failed:
            let failedActions = stages.filter(\.isCurrent).flatMap(\.actions).filter { $0.status == .failed }
            if let first = failedActions.first, failedActions.allSatisfy(\.isRejected) {
                return .rejected(by: first.decidedBy, comment: first.summary)
            }
            return .finished(.failed)
        default:
            return .finished(execution.status)
        }
    }
}
