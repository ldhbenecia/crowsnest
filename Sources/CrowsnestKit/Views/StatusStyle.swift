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

/// 진행 중 — 기본 ProgressView 는 회색이라 강조색으로 직접 그림
/// 반복 애니메이션은 행이 다시 그려질 때마다(갱신 · 호버 · 시각 표시) 끊겨서 각도를 지금 시각으로 매 프레임 계산함
/// 패널이 닫혀 있으면 멈춰서 CPU · 배터리를 안 씀
private struct SpinnerRing: View {
    let tint: Color
    @Environment(\.isPanelVisible) private var isPanelVisible

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isPanelVisible)) { context in
            // 1초에 한 바퀴
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
            Circle()
                .trim(from: 0.15, to: 1)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(1.5)
                .rotationEffect(.degrees(turn * 360))
        }
    }
}

/// 상대 시각은 데이터가 안 바뀌어도 흘러가야 해서 따로 다시 그림
struct RelativeTimeText: View {
    let date: Date
    var prefix = ""
    var suffix = ""

    private static let koreanFormatter = makeFormatter(Locale(identifier: "ko_KR"))
    private static let englishFormatter = makeFormatter(Locale(identifier: "en_US"))

    private static func makeFormatter(_ locale: Locale) -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter
    }

    @Environment(\.isPanelVisible) private var isPanelVisible

    var body: some View {
        TimelineView(.animation(minimumInterval: 30, paused: !isPanelVisible)) { context in
            Text(prefix + Self.describe(date, relativeTo: context.date) + suffix)
        }
    }

    private static func describe(_ date: Date, relativeTo now: Date) -> String {
        guard now.timeIntervalSince(date) >= 60 else { return L("방금", "just now") }
        return (Localization.isKorean ? koreanFormatter : englishFormatter).localizedString(for: date, relativeTo: now)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .noticeChrome()
    }
}

extension View {
    /// 패널 맨 위 안내 줄 공통 모양
    func noticeChrome() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// 인증이 만료된 프로필 — 누르면 aws sso login 이 브라우저를 엶
struct SignInNotice: View {
    let store: PipelineStore
    let profile: String

    private var isSigningIn: Bool { store.signingInProfile == profile }

    var body: some View {
        HStack(spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSigningIn
                        ? L("\(profile) · 브라우저에서 로그인 마저 하기", "\(profile) · Finish signing in in your browser")
                        : L("\(profile) · 인증 만료", "\(profile) · Session expired"))
                    if let error = store.signInErrors[profile], !isSigningIn {
                        Text(error).foregroundStyle(.red).lineLimit(2).textSelection(.enabled)
                    }
                }
            } icon: {
                Image(systemName: "person.badge.key.fill").foregroundStyle(.yellow)
            }
            Spacer(minLength: 0)
            if isSigningIn {
                ProgressView().controlSize(.small)
                Button(L("취소", "Cancel"), action: store.cancelSignIn)
                    .controlSize(.small)
            } else {
                Button(L("로그인", "Sign In")) { store.signIn(profile) }
                    .controlSize(.small)
                    // 한 번에 하나만 — 같은 SSO 세션이면 하나로 다 풀림
                    .disabled(store.signingInProfile != nil)
            }
        }
        .noticeChrome()
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

/// 언어를 바꾸면 안쪽 화면을 통째로 다시 만듦 — L() 문구는 관찰 대상이 아니라 그냥 두면 안 바뀜
struct LanguageScope<Content: View>: View {
    let store: PipelineStore
    @ViewBuilder let content: Content

    var body: some View {
        content.id(store.configuration.language)
    }
}

extension View {
    /// 리스트 행 호버 배경
    func rowHoverBackground(_ isHovered: Bool) -> some View {
        background(.quaternary.opacity(isHovered ? 0.6 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
