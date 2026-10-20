import SwiftUI

/// 패널 안에서 화면을 바꿔서 띄움 — 프로필이 많으면 aws 를 여러 번 불러야 해서 열 때 처음 한 번만 받아옴
struct PipelinePicker: View {
    let store: PipelineStore
    let done: () -> Void
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            FittingScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let catalogError = store.catalogError {
                        NoticeView(message: catalogError)
                    }
                    if store.isLoadingCatalogs && store.catalogs.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(L("aws configure 프로필에서 파이프라인을 불러오는 중", "Loading pipelines from your aws configure profiles"))
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else if store.hasLoadedCatalogs && store.catalogs.isEmpty && store.catalogError == nil {
                        Text(L("aws configure 에 등록된 프로필이 없음", "No profiles in aws configure"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    let selected = Set(store.selection)
                    ForEach(store.catalogs.filter { !$0.isHidden }) { catalog in
                        ProfileSection(store: store, catalog: catalog, query: query, selected: selected)
                    }
                }
                .padding(10)
            }
        }
        .onAppear {
            store.loadCatalogsIfNeeded()
            isSearchFocused = true
        }
        .onExitCommand(perform: done)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ToolbarIconButton(systemName: "chevron.left", help: L("돌아가기", "Back"), action: done)
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField(L("파이프라인 검색", "Search pipelines"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            ToolbarIconButton(
                systemName: "arrow.clockwise",
                help: L("프로필 · 파이프라인 목록 다시 불러오기", "Reload profiles and pipelines"),
                isBusy: store.isLoadingCatalogs,
                action: store.reloadCatalogs
            )
            Button(L("완료", "Done"), action: done)
                .buttonStyle(.borderedProminent)
                .tint(.crowsnestAccent)
                .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }
}

private struct ProfileSection: View {
    let store: PipelineStore
    let catalog: ProfileCatalog
    let query: String
    /// 검색어를 칠 때마다 다시 그려져서 선택 목록 배열을 매번 훑지 않게 받아옴
    let selected: Set<PipelineRef>

    private var matches: [String] {
        query.isEmpty ? catalog.pipelines : catalog.pipelines.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        if query.isEmpty || !matches.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(catalog.profile)
                        .font(.system(size: 11, weight: .semibold))
                    Text(catalog.region)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    let selectedCount = selected.count { $0.profile == catalog.profile && $0.region == catalog.region }
                    if selectedCount > 0 {
                        Text(L("\(selectedCount)개 선택", "\(selectedCount) selected"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 3)
                if let loadError = catalog.loadError {
                    Text(loadError)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
                ForEach(matches, id: \.self) { name in
                    let ref = ref(for: name)
                    PickerRow(name: name, isSelected: selected.contains(ref)) { store.toggle(ref) }
                }
            }
        }
    }

    private func ref(for name: String) -> PipelineRef {
        PipelineRef(profile: catalog.profile, region: catalog.region, name: name)
    }
}

private struct PickerRow: View {
    let name: String
    let isSelected: Bool
    let toggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.crowsnestAccent : Color.secondary.opacity(0.6))
                Text(name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .rowHoverBackground(isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
