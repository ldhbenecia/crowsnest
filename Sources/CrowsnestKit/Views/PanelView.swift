import SwiftUI

struct PanelView: View {
    @Bindable var store: PipelineStore
    @State private var isPicking = false
    /// 끌고 있는 행 — 다른 행 위로 지나갈 때마다 그 자리로 옮김
    @State private var draggingRef: PipelineRef?
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
            ToolbarIconButton(systemName: "arrow.clockwise", help: L("새로고침", "Refresh"), isBusy: store.isRefreshing, action: store.refreshNow)
            ToolbarIconButton(systemName: "plus", help: L("파이프라인 추가 · 빼기", "Add or remove pipelines")) { setPicking(true) }
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
            ForEach(store.profilesNeedingSignIn, id: \.self) { SignInNotice(store: store, profile: $0).padding(.bottom, 6) }
            if let update = store.availableUpdate {
                UpdateNotice(store: store, update: update).padding(.bottom, 6)
            }
            let selection = store.visibleSelection
            if selection.isEmpty {
                EmptyState { setPicking(true) }
            }
            // 프로필이 하나여도 소제목을 띄움 — 안 띄우면 켜도 아무 변화가 없어 보임
            let groups = store.configuration.groupByProfile ? PipelineStore.grouped(selection) : []
            if !groups.isEmpty {
                ForEach(groups, id: \.profile) { group in
                    Text(group.profile)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, group.profile == groups.first?.profile ? 2 : 10)
                        .padding(.bottom, 2)
                    ForEach(group.refs, content: row)
                }
                .environment(\.showsProfileTag, false)
            } else {
                ForEach(selection, content: row)
            }
        }
        .padding(6)
    }

    private func row(_ ref: PipelineRef) -> some View {
        PipelineRow(ref: ref, snapshot: store.snapshots[ref])
            .onDrag {
                draggingRef = ref
                return NSItemProvider(object: ref.id as NSString)
            }
            .onDrop(of: [.plainText], delegate: RowReorderDelegate(target: ref, store: store, draggingRef: $draggingRef))
            .contextMenu {
                Button(L("맨 위로", "Move to Top")) { withAnimation(.snappy) { store.moveToTop(ref) } }
                    .disabled(store.visibleSelection.first == ref)
                Button(L("맨 아래로", "Move to Bottom")) { withAnimation(.snappy) { store.moveToBottom(ref) } }
                    .disabled(store.visibleSelection.last == ref)
                Divider()
                Button(L("AWS 콘솔에서 열기", "Open in AWS Console")) { NSWorkspace.shared.open(ref.consoleURL) }
                Button(L("지켜보기 그만", "Stop Watching")) { withAnimation(.snappy) { store.toggle(ref) } }
            }
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
            let watching = store.visibleSelection.count
            Text(activeCount > 0
                ? L("\(activeCount)개 진행 중", "\(activeCount) running")
                : L("\(watching)개 지켜보는 중", watching == 1 ? "Watching 1 pipeline" : "Watching \(watching) pipelines"))
            if let lastRefreshedAt = store.lastRefreshedAt {
                Text(" · ")
                // 한국어는 "방금 갱신", 영어는 "updated just now" 라 앞뒤가 다름
                RelativeTimeText(date: lastRefreshedAt, prefix: L("", "updated "), suffix: L(" 갱신", ""))
            }
        }
    }
}

private struct PanelMenu: View {
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button(L("설정…", "Settings…")) { SettingsWindow.show() }
                .keyboardShortcut(",")
            Button(L("Crowsnest 정보", "About Crowsnest")) { AboutWindow.show() }
            Divider()
            Button(L("Crowsnest 종료", "Quit Crowsnest")) { NSApplication.shared.terminate(nil) }
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
        .help(L("더 보기", "More"))
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
            Text(L("지켜볼 파이프라인이 없음", "No pipelines to watch"))
                .font(.system(size: 13, weight: .medium))
            Text(L(
                "aws configure 에 등록된 프로필에서 골라 담으면\n배포가 시작 · 승인 대기 · 종료될 때 알려줌",
                "Pick pipelines from your aws configure profiles\nto get notified when deployments need you or finish"
            ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("파이프라인 고르기", "Choose Pipelines"), action: choose)
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(.crowsnestAccent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// 끌던 행이 다른 행 위로 들어오면 바로 그 자리로 옮겨서, 놓기 전에도 순서가 바뀌는 게 보이게
private struct RowReorderDelegate: DropDelegate {
    let target: PipelineRef
    let store: PipelineStore
    @Binding var draggingRef: PipelineRef?

    func dropEntered(info: DropInfo) {
        guard let draggingRef, draggingRef != target else { return }
        // 묶어 볼 때 다른 프로필 행으로 옮기면 행은 제 프로필 아래로 돌아가고 묶음 순서만 바뀌어 보임
        if store.configuration.groupByProfile, draggingRef.profile != target.profile { return }
        withAnimation(.snappy) { store.move(draggingRef, to: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingRef = nil
        return true
    }
}
