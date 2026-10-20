import Foundation

struct DeployNotification: Equatable {
    /// 설정에서 종류별로 끄고 켬
    enum Kind: Equatable {
        case succeeded
        case failed
        /// 중지 · 취소처럼 성공도 실패도 아닌 끝 — 실패 알림 설정을 따름
        case stopped
        case awaitingApproval
        case rejected
    }

    let kind: Kind
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
            if previous.isAwaitingApproval { return nil }
            return DeployNotification(kind: .awaitingApproval, title: "\(name) 승인 필요", body: "\(progress.stage.name) 단계에서 기다리는 중 · \(profile)")
        case .rejected(let decidedBy, _):
            let who = decidedBy.map { "\($0) 님이 " } ?? ""
            return DeployNotification(kind: .rejected, title: "\(name) 배포 반려", body: "\(who)반려함 · \(profile)")
        case .finished(.succeeded):
            let message = snapshot.execution?.revision?.message.map { "\($0) · " } ?? ""
            return DeployNotification(kind: .succeeded, title: "\(name) 배포 완료", body: "\(message)\(profile)")
        case .finished(.failed):
            let failedStage = snapshot.stages.first { $0.isCurrent && $0.status == .failed }
            let place = failedStage.map { "\($0.name) 단계에서 실패 · " } ?? ""
            return DeployNotification(kind: .failed, title: "\(name) 배포 실패", body: "\(place)\(profile)")
        case .finished(let status):
            return DeployNotification(kind: .stopped, title: "\(name) 배포 \(status.label)", body: profile)
        case .running, .unavailable, .neverRun:
            return nil
        }
    }
}
