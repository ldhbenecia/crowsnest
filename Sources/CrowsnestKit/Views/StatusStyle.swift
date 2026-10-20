import SwiftUI

extension Color {
    /// 앱 아이콘과 맞춘 강조색 — 진행 중 표시에 씀
    static let crowsnestAccent = Color.indigo
}

extension PipelineStatus {
    var tint: Color {
        switch self {
        case .succeeded: .green
        case .inProgress: .crowsnestAccent
        case .failed: .red
        case .stopping, .stopped, .cancelled, .superseded, .abandoned, .unknown: .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .succeeded: "checkmark.circle.fill"
        case .inProgress: "circle.dotted.circle"
        case .failed: "xmark.circle.fill"
        case .stopping, .stopped, .cancelled: "stop.circle.fill"
        case .superseded, .abandoned: "arrow.uturn.right.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

/// 파이프라인 · 스테이지 · 액션을 어떻게 그릴지 — 막대 · 아이콘 · 글자색이 다 여기서 정해짐
enum Appearance: Equatable {
    /// 조회 자체가 실패함
    case unavailable
    /// 실행된 적 없거나 끝난 지난 실행 결과
    case notRun
    case running
    case awaitingApproval
    case rejected
    case finished(PipelineStatus)

    var tint: Color {
        switch self {
        case .unavailable: .yellow
        case .notRun: Color(nsColor: .tertiaryLabelColor)
        case .running: .crowsnestAccent
        case .awaitingApproval: .orange
        case .rejected: .secondary
        case .finished(let status): status.tint
        }
    }

    var symbolName: String {
        switch self {
        case .unavailable: "exclamationmark.triangle.fill"
        case .notRun: "circle.dashed"
        case .running: PipelineStatus.inProgress.symbolName
        case .awaitingApproval: "hand.raised.circle.fill"
        case .rejected: "minus.circle.fill"
        case .finished(let status): status.symbolName
        }
    }
}

extension PipelineCondition {
    var appearance: Appearance {
        switch self {
        case .unavailable: .unavailable
        case .neverRun: .notRun
        case .running: .running
        case .awaitingApproval: .awaitingApproval
        case .rejected: .rejected
        case .finished(let status): .finished(status)
        }
    }
}

extension StageSnapshot {
    var appearance: Appearance {
        guard isCurrent, let status else { return .notRun }
        if isAwaitingApproval { return .awaitingApproval }
        if status == .failed && actions.contains(where: \.isRejected) { return .rejected }
        return status == .inProgress ? .running : .finished(status)
    }
}

extension ActionSnapshot {
    var appearance: Appearance {
        if isAwaitingApproval { return .awaitingApproval }
        if isRejected { return .rejected }
        guard let status else { return .notRun }
        return status == .inProgress ? .running : .finished(status)
    }
}

/// 파이프라인 · 스테이지 앞에 붙는 상태 아이콘 — nil 이면 아직 불러오는 중
struct StatusIcon: View {
    let appearance: Appearance?
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch appearance {
            case nil:
                ProgressView().controlSize(.mini)
            case .running:
                SpinnerRing(tint: .crowsnestAccent)
            case let appearance?:
                Image(systemName: appearance.symbolName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(appearance.tint)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Command Line Tools 엔 SwiftUI 매크로 플러그인이 없어서 @Entry 대신 키를 직접 둠
private struct PanelVisibilityKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// 메뉴바 패널은 닫혀도 뷰가 남아 있어서 끝없는 애니메이션을 여기 맞춰 멈춤
    var isPanelVisible: Bool {
        get { self[PanelVisibilityKey.self] }
        set { self[PanelVisibilityKey.self] = newValue }
    }
}

/// 진행 중 — 기본 ProgressView 는 회색이라 강조색으로 직접 그림. 패널이 닫혀 있으면 멈춰서 CPU · 배터리를 안 씀
private struct SpinnerRing: View {
    let tint: Color
    @State private var isRotating = false
    @Environment(\.isPanelVisible) private var isPanelVisible

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 1)
            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .padding(1.5)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear(perform: updateRotation)
            .onChange(of: isPanelVisible) { updateRotation() }
    }

    private func updateRotation() {
        if isPanelVisible {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { isRotating = true }
        } else {
            // 애니메이션 없이 되돌려야 반복이 끊김
            withTransaction(Transaction(animation: nil)) { isRotating = false }
        }
    }
}

/// 상대 시각은 데이터가 안 바뀌어도 흘러가야 해서 따로 다시 그림
struct RelativeTimeText: View {
    let date: Date
    var suffix = ""

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter
    }()

    @Environment(\.isPanelVisible) private var isPanelVisible

    var body: some View {
        TimelineView(.animation(minimumInterval: 30, paused: !isPanelVisible)) { context in
            Text(Self.describe(date, relativeTo: context.date) + suffix)
        }
    }

    private static func describe(_ date: Date, relativeTo now: Date) -> String {
        now.timeIntervalSince(date) < 60 ? "방금" : formatter.localizedString(for: date, relativeTo: now)
    }
}

struct NoticeView: View {
    let message: String

    var body: some View {
        Label {
            Text(message).textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// 헤더 · 툴바용 아이콘 버튼 — 눌리는 영역을 넉넉하게 하고 호버 때만 배경을 깔음
struct ToolbarIconButton: View {
    let systemName: String
    let help: String
    var isBusy = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .frame(width: 26, height: 26)
            .background(.quaternary.opacity(isHovered ? 1 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(isBusy)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

extension View {
    /// 리스트 행 호버 배경
    func rowHoverBackground(_ isHovered: Bool) -> some View {
        background(.quaternary.opacity(isHovered ? 0.6 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
