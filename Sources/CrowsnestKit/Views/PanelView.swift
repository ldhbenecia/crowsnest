import SwiftUI

struct PanelView: View {
    let store: PipelineStore
    @State private var isPickerExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.notices, id: \.self) { NoticeView(message: $0) }
                    if store.selection.isEmpty {
                        Text("지켜볼 파이프라인을 아래에서 골라주셈")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                    ForEach(store.selection) { ref in
                        PipelineCard(ref: ref, snapshot: store.snapshots[ref])
                    }
                    PipelinePicker(store: store, isExpanded: $isPickerExpanded)
                }
                .padding(12)
            }
            .frame(minHeight: 160, maxHeight: 560)
            Divider()
            footer
        }
        .frame(width: 400)
        .onAppear {
            store.refreshIfStale()
            if store.selection.isEmpty {
                isPickerExpanded = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "binoculars.fill")
                .foregroundStyle(.secondary)
            Text("Crowsnest")
                .font(.headline)
            Spacer()
            if let lastRefreshedAt = store.lastRefreshedAt {
                RelativeTimeText(date: lastRefreshedAt, suffix: " 갱신")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("완료 알림", isOn: Binding(
                get: { store.notificationsEnabled },
                set: { store.setNotificationsEnabled($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            Spacer()
            Button {
                NSWorkspace.shared.open(AppConfiguration.fileURL)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("설정 파일 열기 · 바꾸면 재시작해야 반영됨")
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
