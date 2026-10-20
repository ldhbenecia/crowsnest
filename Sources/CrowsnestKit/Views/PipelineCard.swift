import SwiftUI

struct PipelineCard: View {
    let ref: PipelineRef
    let snapshot: PipelineSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                NSWorkspace.shared.open(ref.consoleURL)
            } label: {
                HStack(spacing: 6) {
                    Text((snapshot?.execution?.status).emoji)
                    Text(ref.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(ref.profile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("콘솔에서 열기")

            if let snapshot {
                if let reason = snapshot.failureReason {
                    NoticeView(message: reason)
                } else {
                    if let execution = snapshot.execution {
                        ExecutionLine(execution: execution)
                    }
                    StageProgressBar(stages: snapshot.stages)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(snapshot.stages) { StageRow(stage: $0) }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("불러오는 중")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExecutionLine: View {
    let execution: ExecutionSummary

    var body: some View {
        HStack(spacing: 4) {
            Text(execution.status.label)
                .foregroundStyle(execution.status.tint)
            if let date = execution.updatedAt ?? execution.startedAt {
                Text("·")
                RelativeTimeText(date: date)
            }
            if let revision = execution.revision {
                Text("·")
                if let shortId = revision.shortId {
                    Text(shortId).monospaced()
                }
                if let message = revision.message {
                    Text(message)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(message)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct StageProgressBar: View {
    let stages: [StageSnapshot]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(stages) { stage in
                StageSegment(status: stage.status, isFromLatestExecution: stage.isFromLatestExecution)
            }
        }
        .frame(height: 5)
    }
}

private struct StageSegment: View {
    let status: PipelineStatus?
    let isFromLatestExecution: Bool
    @State private var isDimmed = false

    var body: some View {
        Capsule()
            .fill(isFromLatestExecution ? status.tint : Optional<PipelineStatus>.none.tint)
            .opacity(status == .inProgress && isDimmed ? 0.35 : 1)
            .onAppear(perform: updatePulse)
            .onChange(of: status) { updatePulse() }
    }

    private func updatePulse() {
        guard status == .inProgress else {
            withAnimation(.default) { isDimmed = false }
            return
        }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isDimmed = true }
    }
}

private struct StageRow: View {
    let stage: StageSnapshot
    @State private var isExpanded: Bool

    init(stage: StageSnapshot) {
        self.stage = stage
        _isExpanded = State(initialValue: Self.needsAttention(stage))
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(stage.actions) { ActionRow(action: $0) }
            }
            .padding(.leading, 6)
            .padding(.vertical, 2)
        } label: {
            HStack(spacing: 6) {
                Text(stage.status.emoji)
                Text(stage.name)
                if !stage.isFromLatestExecution && stage.status != nil {
                    Text("이전 실행")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .font(.callout)
            .opacity(stage.isFromLatestExecution ? 1 : 0.55)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { isExpanded.toggle() } }
        }
        .onChange(of: stage.status) {
            if Self.needsAttention(stage) { isExpanded = true }
        }
    }

    /// 진행 중이거나 실패한 스테이지는 액션까지 펼쳐서 보여줌
    private static func needsAttention(_ stage: StageSnapshot) -> Bool {
        stage.isFromLatestExecution && (stage.status == .inProgress || stage.status == .failed)
    }
}

private struct ActionRow: View {
    let action: ActionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("↳ \(action.status.emoji)")
                Text(action.name)
                if let url = action.externalURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right")
                    }
                    .help("빌드 로그 열기")
                }
            }
            if let errorMessage = action.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .textSelection(.enabled)
            } else if let summary = action.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .font(.caption)
    }
}
