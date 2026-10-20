import SwiftUI

extension PipelineStatus {
    var tint: Color { Optional(self).tint }
}

extension Optional where Wrapped == PipelineStatus {
    var tint: Color {
        switch self {
        case .succeeded?: .green
        case .inProgress?: .blue
        case .failed?: .red
        case .stopping?, .stopped?, .cancelled?: .orange
        case .superseded?, .abandoned?, .unknown?: .secondary
        case nil: .gray.opacity(0.35)
        }
    }
}

@MainActor
enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter
    }()

    static func describe(_ date: Date, relativeTo now: Date) -> String {
        now.timeIntervalSince(date) < 60 ? "방금" : formatter.localizedString(for: date, relativeTo: now)
    }
}

/// 상대 시각은 데이터가 안 바뀌어도 흘러가야 해서 따로 다시 그림
struct RelativeTimeText: View {
    let date: Date
    var suffix = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Text(RelativeTime.describe(date, relativeTo: context.date) + suffix)
        }
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
