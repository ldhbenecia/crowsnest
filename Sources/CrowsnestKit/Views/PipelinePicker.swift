import SwiftUI

struct PipelinePicker: View {
    let store: PipelineStore
    @Binding var isExpanded: Bool
    @State private var query = ""

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    TextField("파이프라인 검색", text: $query)
                        .textFieldStyle(.roundedBorder)
                    RefreshButton(
                        isBusy: store.isLoadingCatalogs,
                        help: "프로필 · 파이프라인 목록 다시 불러오기",
                        action: store.reloadCatalogs
                    )
                }
                if let catalogError = store.catalogError {
                    NoticeView(message: catalogError)
                }
                if store.hasLoadedCatalogs && store.catalogs.isEmpty && !store.isLoadingCatalogs && store.catalogError == nil {
                    Text("aws configure 에 등록된 프로필이 없음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.catalogs) { catalog in
                    ProfileSection(store: store, catalog: catalog, query: query)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 4) {
                Text("파이프라인 선택")
                    .font(.callout.weight(.semibold))
                Text("\(store.selection.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .togglesDisclosure($isExpanded)
        }
        .onAppear { if isExpanded { store.loadCatalogsIfNeeded() } }
        .onChange(of: isExpanded) { if isExpanded { store.loadCatalogsIfNeeded() } }
    }
}

private struct ProfileSection: View {
    let store: PipelineStore
    let catalog: ProfileCatalog
    let query: String

    private var matches: [String] {
        query.isEmpty ? catalog.pipelines : catalog.pipelines.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        if query.isEmpty || !matches.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(catalog.profile)
                        .font(.caption.weight(.semibold))
                    Text(catalog.region)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let loadError = catalog.loadError {
                    Text(loadError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                ForEach(matches, id: \.self) { name in
                    let ref = PipelineRef(profile: catalog.profile, region: catalog.region, name: name)
                    Toggle(name, isOn: Binding(
                        get: { store.selection.contains(ref) },
                        set: { _ in store.toggle(ref) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.callout)
                }
            }
        }
    }
}
