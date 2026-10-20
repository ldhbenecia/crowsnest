import Foundation

enum MenuBarTitle {
    /// nil 이면 보여줄 게 없어서 아이콘만 띄움
    static func make(for snapshots: [PipelineSnapshot]) -> String? {
        guard !snapshots.isEmpty else { return nil }

        let running = snapshots.filter { $0.runningStage != nil }
        if let first = running.first, let current = first.runningStage {
            let emoji = first.execution?.status.emoji ?? PipelineStatus.inProgress.emoji
            var title = "\(emoji) \(first.ref.name): \(current.stage.name) \(current.position)/\(first.stages.count)"
            if running.count > 1 {
                title += " ⋯+\(running.count - 1)"
            }
            return title
        }

        let statuses = snapshots.compactMap { $0.execution?.status }
        if statuses.contains(.failed) { return PipelineStatus.failed.emoji }
        if snapshots.contains(where: { $0.failureReason != nil }) { return "⚠️" }
        if statuses.contains(.succeeded) { return PipelineStatus.succeeded.emoji }
        return Optional<PipelineStatus>.none.emoji
    }
}
