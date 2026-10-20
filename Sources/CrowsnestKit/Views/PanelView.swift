import SwiftUI

struct PanelView: View {
    @Bindable var store: PipelineStore
    @State private var isPicking = false
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if isPicking {
                PipelinePicker(store: store) { setPicking(false) }
            } else {
                header
                Divider()
                FittingScrollView { content }
            }
        }
        .frame(width: 400)
        .environment(\.isPanelVisible, isVisible)
        .onAppear {
            isVisible = true
            store.refreshIfStale()
        }
        .onDisappear { isVisible = false }
    }

    private var header: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Crowsnest")
                    .font(.system(size: 13, weight: .semibold))
                HeaderSummary(store: store)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ToolbarIconButton(systemName: "arrow.clockwise", help: "새로고침", isBusy: store.isRefreshing, action: store.refreshNow)
            ToolbarIconButton(systemName: "plus", help: "파이프라인 추가 · 빼기") { setPicking(true) }
            PanelMenu()
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
    }

    private func setPicking(_ isPicking: Bool) {
        withAnimation(.snappy) { self.isPicking = isPicking }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.notices, id: \.self) { NoticeView(message: $0).padding(.bottom, 6) }
            if store.visibleSelection.isEmpty {
                EmptyState { setPicking(true) }
            }
            ForEach(store.visibleSelection) { ref in
                PipelineRow(ref: ref, snapshot: store.snapshots[ref])
            }
        }
        .padding(6)
    }
}

/// ScrollView 는 내용 크기를 안 따라가서 재서 맞춤 — 내용만큼 늘어나다가 화면의 3/4 부터 스크롤
struct FittingScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0
    @State private var maximumHeight: CGFloat = 600

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .frame(height: min(max(contentHeight, 120), maximumHeight))
        .onAppear { maximumHeight = (NSScreen.main?.visibleFrame.height ?? 800) * 0.75 }
    }
}

private struct HeaderSummary: View {
    let store: PipelineStore

    var body: some View {
        let snapshots = store.orderedSnapshots
        let activeCount = snapshots.filter(\.condition.isActive).count
        HStack(spacing: 0) {
            Text(activeCount > 0 ? "\(activeCount)개 진행 중" : "\(store.visibleSelection.count)개 지켜보는 중")
            if let lastRefreshedAt = store.lastRefreshedAt {
                Text(" · ")
                RelativeTimeText(date: lastRefreshedAt, suffix: " 갱신")
            }
        }
    }
}

private struct PanelMenu: View {
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button("설정…") { SettingsWindow.show() }
                .keyboardShortcut(",")
            Button("Crowsnest 정보") { AboutWindow.show() }
            Divider()
            Button("Crowsnest 종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        // 메뉴 라벨 안에 깐 배경은 안 그려져서 바깥에 깔아 옆 버튼들과 같은 호버 모양을 냄
        .background(.quaternary.opacity(isHovered ? 1 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovered = $0 }
        .help("더 보기")
    }
}

private struct EmptyState: View {
    let choose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: CrowsnestGlyph.menuBarImage)
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(.tertiary)
            Text("지켜볼 파이프라인이 없음")
                .font(.system(size: 13, weight: .medium))
            Text("aws configure 에 등록된 프로필에서 골라 담으면\n배포가 시작 · 승인 대기 · 종료될 때 알려줌")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("파이프라인 고르기", action: choose)
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(.crowsnestAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
