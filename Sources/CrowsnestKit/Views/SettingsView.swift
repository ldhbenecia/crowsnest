import AppKit
import SwiftUI

/// 바꾸는 즉시 config.json 에 쓰고 재시작 없이 반영
/// macOS 설정 창처럼 툴바에 아이콘 탭 — SwiftUI TabView 는 가운데 세그먼트로 나와서 AppKit 탭 컨트롤러를 씀
@MainActor
enum SettingsWindow {
    private static let window: AppWindow = {
        let store = PipelineStore.shared
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab("일반", symbol: "gearshape", GeneralSettings(store: store)))
        tabs.addTabViewItem(tab("알림", symbol: "bell", NotificationSettings(store: store)))
        // 프로필이 많으면 끝없이 길어져서 이 탭만 높이를 묶고 안에서 스크롤
        tabs.addTabViewItem(tab("AWS", symbol: "cloud", maximumHeight: 560, AWSSettings(store: store)))
        return AppWindow(title: "설정", hidesTitleBar: false, contentViewController: tabs)
    }()

    static let width: CGFloat = 500

    static func show() {
        window.show()
    }

    /// 탭마다 내용 높이가 달라서 창이 탭을 바꿀 때 그 높이로 맞춰짐
    private static func tab(_ label: String, symbol: String, maximumHeight: CGFloat? = nil, _ content: some View) -> NSTabViewItem {
        let sized = content
            .frame(width: width)
            .frame(maxHeight: maximumHeight)
            .fixedSize(horizontal: false, vertical: maximumHeight == nil)
        let controller = NSHostingController(rootView: sized)
        controller.sizingOptions = .preferredContentSize
        // 탭 컨트롤러가 이 이름을 창 제목으로 올림 — 없으면 Untitled 로 뜸
        controller.title = label
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// 설정 값 하나를 store 에 바로 쓰는 바인딩
@MainActor
private func setting<Value>(_ store: PipelineStore, _ keyPath: WritableKeyPath<AppConfiguration, Value>) -> Binding<Value> {
    Binding(
        get: { store.configuration[keyPath: keyPath] },
        set: { newValue in store.updateConfiguration { $0[keyPath: keyPath] = newValue } }
    )
}

struct GeneralSettings: View {
    let store: PipelineStore
    @State private var loginItem = LoginItem()

    private static let idleIntervals = [15, 30, 60, 120, 300]
    private static let activeIntervals = [5, 10, 15, 30]

    var body: some View {
        Form {
            Section {
                // 메서드를 setter 로 바로 넘기면 Command Line Tools 컴파일러가 죽어서 클로저로 감쌈
                Toggle("로그인할 때 자동으로 실행", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
                if loginItem.needsApproval {
                    HStack {
                        Text("시스템 설정에서 허용해야 켜짐")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("로그인 항목 열기", action: loginItem.openSystemSettings)
                    }
                }
                if let errorMessage = loginItem.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("쉴 때", selection: setting(store, \.pollIntervalSeconds)) {
                    ForEach(Self.options(Self.idleIntervals, current: store.configuration.pollIntervalSeconds), id: \.self) {
                        Text(Self.describe(seconds: $0)).tag($0)
                    }
                }
                Picker("배포 중일 때", selection: setting(store, \.activePollIntervalSeconds)) {
                    ForEach(Self.options(Self.activeIntervals, current: store.configuration.activePollIntervalSeconds), id: \.self) {
                        Text(Self.describe(seconds: $0)).tag($0)
                    }
                }
                Toggle("저전력 모드에서는 두 배로 천천히", isOn: setting(store, \.slowDownInLowPowerMode))
            } header: {
                Text("갱신 주기")
            } footer: {
                Text("화면이 꺼져 있거나 잠겨 있으면 갱신하지 않음")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // 창을 다시 쓰고 있어서, 시스템 설정에서 허용하고 돌아왔을 때도 새로 읽음
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }

    /// 설정 파일에 목록에 없는 값을 적어뒀어도 선택지에 보이게
    private static func options(_ presets: [Int], current: Int) -> [Int] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }

    private static func describe(seconds: Int) -> String {
        seconds < 60 ? "\(seconds)초마다" : "\(seconds / 60)분마다"
    }
}

struct NotificationSettings: View {
    let store: PipelineStore

    var body: some View {
        Form {
            Section {
                Toggle("배포 알림", isOn: setting(store, \.notificationsEnabled))
            } footer: {
                Text("진행 중이던 배포가 끝나거나 승인을 기다리기 시작할 때만 알림 — 앱을 켠 직후엔 울리지 않음")
                    .foregroundStyle(.secondary)
            }

            Section("알림 받을 일") {
                Toggle("배포 완료", isOn: setting(store, \.notifyOnSuccess))
                Toggle("실패 · 중지", isOn: setting(store, \.notifyOnFailure))
                Toggle("승인 필요", isOn: setting(store, \.notifyOnApprovalRequest))
                Toggle("반려", isOn: setting(store, \.notifyOnRejection))
            }
            .disabled(!store.configuration.notificationsEnabled)

            Section {
                Toggle("소리", isOn: setting(store, \.notificationSound))
                    .disabled(!store.configuration.notificationsEnabled)
                HStack {
                    Text("배너 모양 · 집중 모드는 macOS 가 관리함")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("시스템 알림 설정") {
                        let identifier = Bundle.main.bundleIdentifier ?? "com.ldhbenecia.crowsnest"
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(identifier)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AWSSettings: View {
    let store: PipelineStore

    var body: some View {
        Form {
            Section {
                AWSCLIPathRow(store: store)
            } header: {
                Text("aws CLI")
            } footer: {
                Text("프로필 목록과 자격 증명을 읽을 때만 씀 — 파이프라인 조회는 앱이 API 를 직접 부름")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("기본 리전", selection: setting(store, \.defaultRegion)) {
                    RegionOptions(current: store.configuration.defaultRegion)
                }
            } footer: {
                Text("aws configure 에 region 이 없는 프로필(SSO 전용 등)에 씀")
                    .foregroundStyle(.secondary)
            }

            ProfileSettings(store: store)

            Section {
                HStack {
                    Text("모든 설정은 config.json 에 저장됨")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Finder 에서 보기") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppConfiguration.fileURL])
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// aws configure 에 등록된 프로필마다 보이기 · 리전 덮어쓰기
private struct ProfileSettings: View {
    let store: PipelineStore

    var body: some View {
        Section {
            if store.catalogs.isEmpty {
                HStack(spacing: 8) {
                    if store.isLoadingCatalogs {
                        ProgressView().controlSize(.small)
                    }
                    Text(store.isLoadingCatalogs ? "프로필을 불러오는 중" : store.catalogError ?? "aws configure 에 등록된 프로필이 없음")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(store.catalogs) { catalog in
                HStack(spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { !store.configuration.hiddenProfiles.contains(catalog.profile) },
                        set: { isVisible in
                            store.updateConfiguration { configuration in
                                configuration.hiddenProfiles.removeAll { $0 == catalog.profile }
                                if !isVisible { configuration.hiddenProfiles.append(catalog.profile) }
                            }
                        }
                    )) {
                        Text(catalog.profile)
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                    Picker("리전", selection: Binding(
                        get: { store.configuration.regionOverrides[catalog.profile] },
                        set: { region in store.updateConfiguration { $0.regionOverrides[catalog.profile] = region } }
                    )) {
                        // 덮어쓰지 않았을 때 catalog.region 은 aws configure 에서 읽은 값
                        let configured = store.configuration.regionOverrides[catalog.profile] == nil ? " (\(catalog.region))" : ""
                        Text("aws configure 따름\(configured)").tag(String?.none)
                        Divider()
                        RegionOptions(current: store.configuration.regionOverrides[catalog.profile], asOptional: true)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        } header: {
            HStack {
                Text("프로필")
                Spacer()
                ToolbarIconButton(
                    systemName: "arrow.clockwise",
                    help: "프로필 목록 다시 불러오기",
                    isBusy: store.isLoadingCatalogs,
                    action: store.reloadCatalogs
                )
            }
        } footer: {
            Text("체크를 끄면 그 프로필의 파이프라인이 패널 · 선택 목록에서 빠지고 조회도 안 함(다시 켜면 돌아옴)")
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: store.loadCatalogsIfNeeded)
    }
}

/// 쓰는 aws 경로 — 직접 칠 일 없이 Finder 에서 고르고, 자동으로 찾기로 되돌림
private struct AWSCLIPathRow: View {
    let store: PipelineStore
    @State private var pickError: String?

    private var isCustom: Bool { store.configuration.awsCLIPath != nil }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.awsCLIPath ?? "못 찾음")
                        .foregroundStyle(store.awsCLIPath == nil ? .orange : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Text(isCustom ? "직접 고른 경로" : "brew · 기본 경로에서 자동으로 찾음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("변경…", action: choose)
                if isCustom {
                    Button("자동으로") { store.updateConfiguration { $0.awsCLIPath = nil } }
                }
            }
        } label: {
            Text("실행 파일")
            if let pickError {
                Text(pickError)
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.message = "aws 실행 파일을 고르셈 (터미널에서 which aws 로 확인)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        // /opt/homebrew/bin 같은 숨김 경로도 보여야 고를 수 있음
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: store.awsCLIPath.map { ($0 as NSString).deletingLastPathComponent } ?? "/usr/local/bin")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path(percentEncoded: false)
        guard FileManager.default.isExecutableFile(atPath: path) else {
            pickError = "실행할 수 있는 파일이 아님"
            return
        }
        pickError = nil
        store.updateConfiguration { $0.awsCLIPath = path }
    }
}

/// 리전 목록 — 설정 파일에 목록에 없는 리전을 적어뒀어도 선택지에 보이게
private struct RegionOptions: View {
    let current: String?
    var asOptional = false

    private var codes: [String] {
        let known = AWSRegion.known.map(\.code)
        guard let current, !known.contains(current) else { return known }
        return [current] + known
    }

    var body: some View {
        ForEach(codes, id: \.self) { code in
            if asOptional {
                Text(AWSRegion.label(code)).tag(String?.some(code))
            } else {
                Text(AWSRegion.label(code)).tag(code)
            }
        }
    }
}
