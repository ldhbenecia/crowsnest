import Foundation

struct DeployNotification: Equatable {
    let title: String
    let body: String

    /// 돌던 실행이 끝났거나 승인을 기다리기 시작했을 때만 — 앱을 켠 직후 첫 조회에선 안 울림
    static func make(previous: PipelineCondition?, snapshot: PipelineSnapshot) -> DeployNotification? {
        guard let previous, previous.isActive else { return nil }
        let name = snapshot.ref.name
        let profile = snapshot.ref.profile

        switch snapshot.condition {
        case .awaitingApproval(let progress):
            // 스테이지 안 필드가 바뀌어도 같은 대기라 이전 상태 종류만 봄
            if case .awaitingApproval = previous { return nil }
            return DeployNotification(title: "\(name) 승인 필요", body: "\(progress.stage.name) 단계에서 기다리는 중 · \(profile)")
        case .rejected(let decidedBy):
            let who = decidedBy.map { "\($0) 님이 " } ?? ""
            return DeployNotification(title: "\(name) 배포 반려", body: "\(who)반려함 · \(profile)")
        case .finished(.succeeded):
            let message = snapshot.execution?.revision?.message.map { "\($0) · " } ?? ""
            return DeployNotification(title: "\(name) 배포 완료", body: "\(message)\(profile)")
        case .finished(.failed):
            let failedStage = snapshot.stages.first { $0.isCurrent && $0.status == .failed }
            let place = failedStage.map { "\($0.name) 단계에서 실패 · " } ?? ""
            return DeployNotification(title: "\(name) 배포 실패", body: "\(place)\(profile)")
        case .finished(let status):
            return DeployNotification(title: "\(name) 배포 \(status.label)", body: profile)
        case .running, .unavailable, .neverRun:
            return nil
        }
    }
}
