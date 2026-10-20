import Foundation

/// 메뉴바에 뜨는 것 — 쉴 땐 글리프, 돌고 있으면 작은 이름과 스테이지 막대를 두 줄로
enum MenuBarStatus: Equatable {
    case idle
    /// 실패 · 조회 실패 — 글리프에 점만 찍고 자세한 건 패널에서
    case needsAttention
    case active(ActivePipeline)

    struct ActivePipeline: Equatable {
        let name: String
        /// 스테이지 사이를 넘어가는 순간엔 nil
        let progress: StagePosition?
        let isAwaitingApproval: Bool
        /// 같이 돌고 있는 나머지 파이프라인 수
        let othersCount: Int
    }

    struct StagePosition: Equatable {
        /// 1부터
        let position: Int
        let count: Int
    }

    /// 노치 맥은 메뉴바 아이템이 자리가 모자라면 통째로 숨겨져서 길이를 묶어 둠
    static let pipelineNameLimit = 24

    /// 사람 손이 필요한 승인 대기 → 진행 중 → 실패 · 조회 실패 순으로 하나만 고름
    static func make(for snapshots: [PipelineSnapshot]) -> MenuBarStatus {
        let active = snapshots.filter { $0.condition.isActive }
        if let shown = active.first(where: \.condition.isAwaitingApproval) ?? active.first {
            return .active(ActivePipeline(
                // 파이프라인 이름은 끝(-prod · -test)으로 구분되는 경우가 많아서 가운데를 자름
                name: shown.ref.name.truncated(to: pipelineNameLimit, keepingTail: (pipelineNameLimit - 1) / 2),
                progress: shown.condition.progress.map { StagePosition(position: $0.position, count: $0.count) },
                isAwaitingApproval: shown.condition.isAwaitingApproval,
                othersCount: active.count - 1
            ))
        }
        return snapshots.contains(where: \.condition.needsAttention) ? .needsAttention : .idle
    }
}
