import SwiftUI

/// 파이프라인 한 줄 — 평소엔 요약과 스테이지 막대만, 눌러야 스테이지 · 액션을 다 펼침
struct PipelineRow: View {
    let ref: PipelineRef
    let snapshot: PipelineSnapshot?
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            titleLine
            if let snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    if let execution = snapshot.execution {
                        RevisionLine(profile: ref.profile, execution: execution)
                    }
                    if !snapshot.stages.isEmpty {
                        StageTrack(stages: snapshot.stages)
                    }
                    AttentionDetail(snapshot: snapshot)
                    if isExpanded {
                        StageList(stages: snapshot.stages)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .rowHoverBackground(isHovered)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() } }
        .onHover { isHovered = $0 }
    }

    private var titleLine: some View {
        HStack(spacing: 8) {
            StatusIcon(appearance: snapshot?.condition.appearance)
            Text(ref.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            // 성공은 아이콘만으로 충분해서 글은 뺌
            if let snapshot, snapshot.condition != .finished(.succeeded) {
                Text(snapshot.condition.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(snapshot.condition.appearance.tint)
            }
            Spacer(minLength: 4)
            if let date = snapshot?.execution.flatMap({ $0.updatedAt ?? $0.startedAt }) {
                RelativeTimeText(date: date)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Button {
                NSWorkspace.shared.open(ref.consoleURL)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 1 : 0)
            .help(L("AWS 콘솔에서 열기", "Open in AWS Console"))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }
}

private struct RevisionLine: View {
    let profile: String
    let execution: ExecutionSummary
    @Environment(\.showsProfileTag) private var showsProfileTag

    var body: some View {
        HStack(spacing: 6) {
            if showsProfileTag {
                Text(profile)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if let shortId = execution.revision?.shortId {
                Text(shortId).monospaced()
            }
            if let message = execution.revision?.message {
                Text(message)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(message)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

/// 스테이지마다 칸 하나 — 지난 실행 결과는 안 돈 것처럼 비워둠
private struct StageTrack: View {
    let stages: [StageSnapshot]

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(stages) { stage in
                let appearance = stage.appearance
                VStack(alignment: .leading, spacing: 4) {
                    // 안 돈 칸은 아이콘용 회색보다 더 옅게 깔아서 빈 칸처럼 보이게
                    Capsule()
                        .fill(appearance == .notRun ? Color.primary.opacity(0.1) : appearance.tint)
                        .frame(height: 4)
                    Text(stage.name)
                        .font(.system(size: 10, weight: appearance == .running ? .semibold : .regular))
                        .foregroundStyle(stage.isCurrent ? .secondary : .tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// 사람이 봐야 하는 것만 접힌 상태에서도 보여줌
private struct AttentionDetail: View {
    let snapshot: PipelineSnapshot

    var body: some View {
        switch snapshot.condition {
        case .running(let progress?):
            ForEach(progress.stage.actions.filter { $0.status == .inProgress }) { action in
                ActionLine(action: action, caption: L("진행 중", "running"))
            }
        case .awaitingApproval(let progress):
            HStack(spacing: 8) {
                Text(L("\(progress.stage.name) 단계에서 승인을 기다리는 중", "Waiting for approval at \(progress.stage.name)"))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(L("콘솔에서 승인", "Approve in Console")) { NSWorkspace.shared.open(snapshot.ref.consoleURL) }
                    .controlSize(.small)
            }
            .font(.system(size: 11))
        case .rejected(let decidedBy, let comment):
            Text([decidedBy.map { L("\($0) 님이 반려함", "Rejected by \($0)") } ?? L("반려됨", "Rejected"), comment].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .finished(.failed):
            ForEach(snapshot.stages.filter(\.isCurrent).flatMap(\.actions).filter { $0.status == .failed }) { action in
                ActionLine(action: action, caption: nil)
            }
        case .unavailable(let reason):
            Text(reason)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .running(nil), .neverRun, .finished:
            EmptyView()
        }
    }
}

/// 액션 이름 · 로그 링크 · 에러 메시지
private struct ActionLine: View {
    let action: ActionSnapshot
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(action.name).fontWeight(.medium)
                if let caption {
                    Text(caption).foregroundStyle(.secondary)
                }
                if let url = action.externalURL {
                    LogLink(url: url, showsTitle: true)
                }
            }
            if let errorMessage = action.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
            } else if let summary = action.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .font(.system(size: 11))
    }
}

private struct LogLink: View {
    let url: URL
    let showsTitle: Bool

    var body: some View {
        Link(destination: url) {
            if showsTitle {
                Label(L("로그", "Logs"), systemImage: "arrow.up.right")
            } else {
                Image(systemName: "arrow.up.right")
            }
        }
        .foregroundStyle(Color.crowsnestAccent)
        .help(L("빌드 로그 열기", "Open build logs"))
    }
}

/// 펼쳤을 때 — 스테이지마다 액션까지
private struct StageList: View {
    let stages: [StageSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(stages) { stage in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        StatusIcon(appearance: stage.appearance, size: 11)
                        Text(stage.name).font(.system(size: 11, weight: .medium))
                        if !stage.isCurrent && stage.status != nil {
                            Text(L("이전 실행", "previous run")).font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                    }
                    ForEach(stage.actions) { action in
                        HStack(spacing: 6) {
                            StatusIcon(appearance: action.appearance, size: 9)
                            Text(action.name)
                            if let url = action.externalURL {
                                LogLink(url: url, showsTitle: false)
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 17)
                    }
                }
                .opacity(stage.isCurrent ? 1 : 0.6)
            }
        }
        .padding(.top, 2)
    }
}
