import Foundation

enum MenuBarTitle {
    /// 노치 맥은 메뉴바 아이템이 자리가 모자라면 통째로 숨겨져서 길이를 묶어 둠
    static let pipelineNameLimit = 24
    static let stageNameLimit = 12

    /// nil 이면 보여줄 게 없어서 아이콘만 띄움
    static func make(for snapshots: [PipelineSnapshot]) -> String? {
        guard !snapshots.isEmpty else { return nil }

        let running = snapshots.compactMap { snapshot in snapshot.runningStage.map { (snapshot, $0) } }
        if let (first, current) = running.first {
            let emoji = first.execution?.status.emoji ?? PipelineStatus.inProgress.emoji
            // 파이프라인 이름은 끝(-prod · -test)으로 구분되는 경우가 많아서 가운데를 자름
            let name = first.ref.name.truncated(to: pipelineNameLimit, keepingTail: (pipelineNameLimit - 1) / 2)
            let stage = current.stage.name.truncated(to: stageNameLimit)
            var title = "\(emoji) \(name): \(stage) \(current.position)/\(first.stages.count)"
            if running.count > 1 {
                title += " ⋯+\(running.count - 1)"
            }
            return title
        }

        let statuses = snapshots.compactMap { $0.execution?.status }
        if statuses.contains(.failed) { return PipelineStatus.failed.emoji }
        if snapshots.contains(where: { $0.failureReason != nil }) { return "⚠️" }
        if statuses.contains(.succeeded) { return PipelineStatus.succeeded.emoji }
        return PipelineStatus.neverRunEmoji
    }
}
