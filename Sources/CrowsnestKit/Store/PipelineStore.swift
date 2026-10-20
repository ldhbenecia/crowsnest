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
    var notificationsEnabled: Bool {
        didSet { Preferences.notificationsMuted = !notificationsEnabled }
    }
    /// 설정 파일 · aws CLI 문제처럼 패널 맨 위에 띄울 것
    let notices: [String]

    @ObservationIgnored private let configuration: AppConfiguration
    @ObservationIgnored private let service: CodePipelineService?
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private var previousConditions: [PipelineRef: PipelineCondition] = [:]
    /// 이걸 취소하면 폴링 루프가 기다리지 않고 바로 다음 갱신으로 넘어감
    @ObservationIgnored private var pendingSleep: Task<Void, Never>?
    /// 갱신 도중에 들어온 요청 — 끝나자마자 한 번 더 돌게
    @ObservationIgnored private var isRefreshRequested = false
    /// 화면이 꺼졌거나 잠겼을 때 — 아무도 안 보니 폴링을 멈춤
    @ObservationIgnored private var isSuspended = false

    private init() {
        let loaded = AppConfiguration.load()
        configuration = loaded.configuration
        var notices = loaded.error.map { [$0] } ?? []
        if let cli = AWSCommandLine.locate(preferredPath: loaded.configuration.awsCLIPath) {
            service = CodePipelineService(cli: cli, configuration: loaded.configuration)
        } else {
            service = nil
            notices.append("aws CLI 를 못 찾음 · brew install awscli 또는 config.json 에 awsCLIPath 지정")
        }
        self.notices = notices
        selection = Preferences.selection
        notificationsEnabled = !Preferences.notificationsMuted
        notifier = Notifier()
        observeScreenAndSession()
        startPolling()
    }

    var orderedSnapshots: [PipelineSnapshot] {
        selection.compactMap { snapshots[$0] }
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

    func reloadCatalogs() {
        guard let service, !isLoadingCatalogs else { return }
        hasLoadedCatalogs = true
        isLoadingCatalogs = true
        Task {
            do {
                catalogs = try await service.loadCatalogs()
                catalogError = nil
            } catch {
                catalogError = error.localizedDescription
                logger.error("프로필 목록 조회 실패 · \(error.localizedDescription, privacy: .public)")
            }
            isLoadingCatalogs = false
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
        let targets = selection
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
        guard notificationsEnabled, let notification = DeployNotification.make(previous: previous, snapshot: snapshot) else { return }
        logger.info("\(snapshot.ref.id, privacy: .public) \(condition.label, privacy: .public)")
        notifier.post(title: notification.title, body: notification.body, link: snapshot.ref.consoleURL)
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
        let multiplier = ProcessInfo.processInfo.isLowPowerModeEnabled ? 2 : 1
        return .seconds(max(5, seconds) * multiplier)
    }
}
