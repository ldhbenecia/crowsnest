import SwiftUI

extension PipelineStatus {
    var tint: Color {
        switch self {
        case .succeeded: .green
        case .inProgress: .blue
        case .failed: .red
        case .stopping, .stopped, .cancelled: .orange
        case .superseded, .abandoned, .unknown: .secondary
        }
    }
}

extension Optional where Wrapped == PipelineStatus {
    /// 실행된 적 없는 스테이지
    var tint: Color { self?.tint ?? .gray.opacity(0.35) }
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
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
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct RefreshButton: View {
    let isBusy: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.borderless)
        .disabled(isBusy)
        .help(help)
    }
}

extension View {
    /// DisclosureGroup 은 기본으로 화살표만 눌려서 라벨 전체를 누를 수 있게 함
    func togglesDisclosure(_ isExpanded: Binding<Bool>) -> some View {
        contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { isExpanded.wrappedValue.toggle() } }
    }
}
