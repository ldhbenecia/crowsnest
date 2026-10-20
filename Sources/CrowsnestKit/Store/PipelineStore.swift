import AppKit
import Observation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ldhbenecia.crowsnest", category: "store")

@MainActor
@Observable
final class PipelineStore {
    static let shared = PipelineStore()

    private(set) var selection: [PipelineRef]
    private(set) var snapshots: [PipelineRef: PipelineSnapshot] = [:]
    private(set) var catalogs: [ProfileCatalog] = []
    private(set) var catalogError: String?
    private(set) var isLoadingCatalogs = false
    private(set) var isRefreshing = false
    private(set) var lastRefreshedAt: Date?
    private(set) var hasLoadedCatalogs = false
    private(set) var configuration: AppConfiguration
    /// 찾은 aws 실행 파일 — 설정 창에 보여줌, nil 이면 못 찾은 것
    private(set) var awsCLIPath: String?
    /// config.json 을 못 읽은 원인
    private let configurationLoadError: String?

    /// 설정 파일 · aws CLI 문제처럼 패널 맨 위에 띄울 것 — 언어를 바꾸면 바로 다시 그려지게 그때그때 만듦
    var notices: [String] {
        var notices: [String] = []
        if let configurationLoadError {
            notices.append(L(
                "config.json 을 못 읽어서 기본값으로 실행 중 · \(configurationLoadError)",
                "Couldn't read config.json, running with defaults · \(configurationLoadError)"
            ))
        }
        if awsCLIPath == nil {
            notices.append(L(
                "aws CLI 를 못 찾음 · brew install awscli 또는 설정 → AWS 에서 경로 지정",
                "aws CLI not found · install it with brew install awscli or choose it in Settings → AWS"
            ))
        }
        return notices
    }

    @ObservationIgnored private var service: CodePipelineService?
    /// 미리보기 스토어는 알림 권한을 묻지 않게 nil
    @ObservationIgnored private let notifier: Notifier?
    @ObservationIgnored private var previousConditions: [PipelineRef: PipelineCondition] = [:]
    /// 이걸 취소하면 폴링 루프가 기다리지 않고 바로 다음 갱신으로 넘어감
    @ObservationIgnored private var pendingSleep: Task<Void, Never>?
    /// 갱신 도중에 들어온 요청 — 끝나자마자 한 번 더 돌게
    @ObservationIgnored private var isRefreshRequested = false
    /// 화면이 꺼졌거나 잠겼을 때 — 아무도 안 보니 폴링을 멈춤
    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var isCatalogReloadPending = false

    private init() {
        let loaded = AppConfiguration.load()
        var configuration = loaded.configuration
        if Preferences.takeLegacyNotificationsMuted() {
            configuration.notificationsEnabled = false
            try? configuration.save()
        }
        self.configuration = configuration
        configurationLoadError = loaded.error
        Localization.apply(configuration.language)
        selection = Preferences.selection
        notifier = Notifier()
        connect()
        observeScreenAndSession()
        startPolling()
    }

    #if DEBUG
    /// 미리보기 · 스크린샷용 고정 데이터 — aws 를 안 부르고 폴링 · 알림도 안 함. 배포 빌드엔 안 들어감
    init(previewSnapshots: [PipelineSnapshot], catalogs: [ProfileCatalog] = [], refreshedAt: Date) {
        configuration = AppConfiguration()
        configurationLoadError = nil
        service = nil
        awsCLIPath = "/opt/homebrew/bin/aws"
        notifier = nil
        self.catalogs = catalogs
        hasLoadedCatalogs = true
        selection = previewSnapshots.map(\.ref)
        snapshots = Dictionary(uniqueKeysWithValues: previewSnapshots.map { ($0.ref, $0) })
        lastRefreshedAt = refreshedAt
    }
    #endif

    /// aws CLI 를 찾아 서비스를 새로 만듦 — aws 경로가 바뀔 때만. 자격 증명 캐시가 같이 새로 시작해서 리전 · 숨김 변경엔 안 부름
    private func connect() {
        let cli = AWSCommandLine.locate(preferredPath: configuration.awsCLIPath)
        service = cli.map(CodePipelineService.init(cli:))
        awsCLIPath = cli?.executableURL.path(percentEncoded: false)
    }

    /// 설정 창에서 바꾼 값 — 파일에 쓰고 재시작 없이 바로 반영
    func updateConfiguration(_ change: (inout AppConfiguration) -> Void) {
        var updated = configuration
        change(&updated)
        guard updated != configuration else { return }
        let previous = configuration
        configuration = updated
        do {
            try updated.save()
        } catch {
            logger.error("설정 저장 실패 · \(error.localizedDescription, privacy: .public)")
        }
        if updated.language != previous.language {
            Localization.apply(updated.language)
        }
        let pathChanged = updated.awsCLIPath != previous.awsCLIPath
        let regionsChanged = updated.defaultRegion != previous.defaultRegion || updated.regionOverrides != previous.regionOverrides
        // 숨기기는 목록에서 빼기만 하면 되고, 다시 보이게 할 때만 그 프로필의 파이프라인을 받아와야 함
        let unhidden = !Set(previous.hiddenProfiles).subtracting(updated.hiddenProfiles).isEmpty
        if pathChanged {
            connect()
        }
        if pathChanged || regionsChanged || unhidden {
            if hasLoadedCatalogs { reloadCatalogs() }
        } else if updated.hiddenProfiles != previous.hiddenProfiles {
            catalogs = catalogs.map { catalog in
                var catalog = catalog
                catalog.isHidden = updated.hiddenProfiles.contains(catalog.profile)
                return catalog
            }
        }
        // 알림 · 소리 같은 건 다음 조회를 기다려도 됨 — 바로 조회하는 건 결과가 달라지는 설정만
        if pathChanged || regionsChanged || updated.hiddenProfiles != previous.hiddenProfiles
            || updated.pollIntervalSeconds != previous.pollIntervalSeconds
            || updated.activePollIntervalSeconds != previous.activePollIntervalSeconds {
            requestRefresh()
        }
    }

    /// 숨긴 프로필의 파이프라인은 선택은 남겨두고(다시 보이면 돌아오게) 화면 · 조회에서만 뺌
    var visibleSelection: [PipelineRef] {
        selection.filter { !configuration.hiddenProfiles.contains($0.profile) }
    }

    var orderedSnapshots: [PipelineSnapshot] {
        visibleSelection.compactMap { snapshots[$0] }
    }

    var menuBarStatus: MenuBarStatus {
        MenuBarStatus.make(for: orderedSnapshots)
    }

    /// 선택 변경 · 패널 열기 — 폴링 대기를 깨워서 바로 갱신
    func requestRefresh() {
        isRefreshRequested = true
        pendingSleep?.cancel()
    }

    func refreshNow() {
        Task {
            await service?.forgetCredentialFailures()
            requestRefresh()
        }
    }

    /// 패널을 열 때 — 방금 갱신했으면 안 깨움
    func refreshIfStale() {
        let isFresh = lastRefreshedAt.map { Date.now.timeIntervalSince($0) < 5 } ?? false
        if !isFresh {
            requestRefresh()
        }
    }

    /// 프로필이 많으면 aws 프로세스를 여러 개 띄워야 해서 선택 UI 를 처음 펼칠 때까지 미룸
    func loadCatalogsIfNeeded() {
        guard !hasLoadedCatalogs else { return }
        reloadCatalogs()
    }

    /// 불러오는 도중에 설정이 바뀌면 그 결과는 옛 설정 기준이라 버리고 끝나자마자 다시 불러옴
    func reloadCatalogs() {
        guard let service else { return }
        guard !isLoadingCatalogs else {
            isCatalogReloadPending = true
            return
        }
        hasLoadedCatalogs = true
        isLoadingCatalogs = true
        let requested = configuration
        Task {
            let result: Result<[ProfileCatalog], any Error>
            do {
                result = .success(try await service.loadCatalogs(using: requested))
            } catch {
                result = .failure(error)
            }
            isLoadingCatalogs = false
            if isCatalogReloadPending {
                isCatalogReloadPending = false
                reloadCatalogs()
                return
            }
            switch result {
            case .success(let loaded):
                catalogs = loaded
                catalogError = nil
                followRegionChanges()
            case .failure(let error):
                catalogError = error.localizedDescription
                logger.error("프로필 목록 조회 실패 · \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// 프로필 리전을 바꾸면 이미 고른 파이프라인도 새 리전을 가리키게 — 새 리전에도 같은 이름이 있을 때만
    private func followRegionChanges() {
        let followed = Self.selection(selection, followingRegionsOf: catalogs)
        guard followed != selection else { return }
        for ref in selection where !followed.contains(ref) {
            snapshots[ref] = nil
            previousConditions[ref] = nil
        }
        selection = followed
        Preferences.selection = selection
        requestRefresh()
    }

    nonisolated static func selection(_ selection: [PipelineRef], followingRegionsOf catalogs: [ProfileCatalog]) -> [PipelineRef] {
        selection.map { ref in
            guard let catalog = catalogs.first(where: { $0.profile == ref.profile }),
                  catalog.region != ref.region, catalog.pipelines.contains(ref.name) else { return ref }
            return PipelineRef(profile: ref.profile, region: catalog.region, name: ref.name)
        }
    }

    func toggle(_ ref: PipelineRef) {
        if let index = selection.firstIndex(of: ref) {
            selection.remove(at: index)
            snapshots[ref] = nil
            previousConditions[ref] = nil
        } else {
            selection.append(ref)
            requestRefresh()
        }
        Preferences.selection = selection
    }

    /// 갱신은 이 루프에서만 함 — 다른 곳은 requestRefresh 로 대기만 깨움
    private func startPolling() {
        Task {
            while true {
                if isSuspended {
                    await wait(for: .seconds(3600))
                    continue
                }
                isRefreshRequested = false
                await refresh()
                guard !isRefreshRequested else { continue }
                await wait(for: pollInterval)
            }
        }
    }

    /// requestRefresh 가 취소하면 바로 깸 — 여유 시간을 줘서 시스템이 다른 깨어남과 묶어 처리하게 함
    private func wait(for interval: Duration) async {
        let sleep = Task { _ = try? await Task.sleep(for: interval, tolerance: interval / 5) }
        pendingSleep = sleep
        await sleep.value
    }

    /// 화면이 꺼진 동안 끝난 배포는 깨어나자마자 한 번 조회해서 그때 알림
    private func observeScreenAndSession() {
        let changes: [(Notification.Name, isSuspended: Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.sessionDidResignActiveNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.sessionDidBecomeActiveNotification, false),
        ]
        for (name, isSuspended) in changes {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    self.isSuspended = isSuspended
                    if !isSuspended { self.requestRefresh() }
                }
            }
        }
    }

    private func refresh() async {
        guard let service else { return }
        let targets = visibleSelection
        let previous = snapshots
        isRefreshing = true
        let fresh = await withTaskGroup(of: PipelineSnapshot.self) { group in
            for ref in targets {
                group.addTask { [previous = previous[ref]] in await service.snapshot(of: ref, previous: previous) }
            }
            // MainActor 안이라 group.reduce 는 Swift 6 동시성 검사에 걸림
            var collected: [PipelineSnapshot] = []
            for await snapshot in group {
                collected.append(snapshot)
            }
            return collected
        }
        isRefreshing = false
        apply(fresh)
        lastRefreshedAt = .now
    }

    /// 조회하는 사이에 선택 해제된 건 버림
    private func apply(_ fresh: [PipelineSnapshot]) {
        for snapshot in fresh where selection.contains(snapshot.ref) {
            if let reason = snapshot.failureReason {
                logger.error("\(snapshot.ref.id, privacy: .public) 조회 실패 · \(reason, privacy: .private)")
            }
            notifyIfChanged(snapshot)
            if snapshots[snapshot.ref] != snapshot {
                snapshots[snapshot.ref] = snapshot
            }
        }
    }

    private func notifyIfChanged(_ snapshot: PipelineSnapshot) {
        let condition = snapshot.condition
        // 조회 실패는 상태를 모르는 것 — 직전 상태를 남겨둬야 인증이 풀린 뒤 끝난 실행도 알림
        if condition.isUnavailable { return }
        let previous = previousConditions.updateValue(condition, forKey: snapshot.ref)
        guard let notification = DeployNotification.make(previous: previous, snapshot: snapshot),
              configuration.allows(notification.kind) else { return }
        logger.info("\(snapshot.ref.id, privacy: .public) \(condition.label, privacy: .public)")
        notifier?.post(
            title: notification.title,
            body: notification.body,
            link: snapshot.ref.consoleURL,
            playsSound: configuration.notificationSound
        )
    }

    private var pollInterval: Duration {
        let current = Array(snapshots.values)
        // 인증 만료 · 오프라인이면 전부 같은 이유로 실패하니 천천히 — 새로고침 버튼으로 바로 다시 볼 수 있음
        if !current.isEmpty && current.allSatisfy({ $0.failureReason != nil }) {
            return .seconds(300)
        }
        let isAnyRunning = current.contains { $0.condition.isActive }
        let seconds = isAnyRunning ? configuration.activePollIntervalSeconds : configuration.pollIntervalSeconds
        // 저전력 모드면 배터리를 아끼라는 뜻이라 두 배로 늘림
        let multiplier = configuration.slowDownInLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled ? 2 : 1
        return .seconds(max(5, seconds) * multiplier)
    }
}
