import Foundation
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
    @ObservationIgnored private var previousStatuses: [PipelineRef: PipelineStatus] = [:]
    /// 이걸 취소하면 폴링 루프가 기다리지 않고 바로 다음 갱신으로 넘어감
    @ObservationIgnored private var pendingSleep: Task<Void, Never>?
    /// 갱신 도중에 들어온 요청 — 끝나자마자 한 번 더 돌게
    @ObservationIgnored private var isRefreshRequested = false

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
        startPolling()
    }

    var orderedSnapshots: [PipelineSnapshot] {
        selection.compactMap { snapshots[$0] }
    }

    var menuBarTitle: String? {
        MenuBarTitle.make(for: orderedSnapshots)
    }

    /// 버튼 · 선택 변경 — 폴링 대기를 깨워서 바로 갱신
    func requestRefresh() {
        isRefreshRequested = true
        pendingSleep?.cancel()
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
            previousStatuses[ref] = nil
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
                isRefreshRequested = false
                await refresh()
                guard !isRefreshRequested else { continue }
                let sleep = Task { [interval = pollInterval] in _ = try? await Task.sleep(for: interval) }
                pendingSleep = sleep
                await sleep.value
            }
        }
    }

    private func refresh() async {
        guard let service else { return }
        let targets = selection
        isRefreshing = true
        let fresh = await withTaskGroup(of: PipelineSnapshot.self) { group in
            for ref in targets {
                group.addTask { await service.snapshot(of: ref) }
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
                logger.error("\(snapshot.ref.id, privacy: .public) 조회 실패 · \(reason, privacy: .public)")
            }
            notifyIfFinished(snapshot)
            if snapshots[snapshot.ref] != snapshot {
                snapshots[snapshot.ref] = snapshot
            }
        }
    }

    /// 진행 중이던 실행이 끝났을 때만 알림 — 앱을 켠 직후 첫 조회에선 안 울림
    private func notifyIfFinished(_ snapshot: PipelineSnapshot) {
        guard let status = snapshot.execution?.status else { return }
        let previous = previousStatuses.updateValue(status, forKey: snapshot.ref)
        guard notificationsEnabled, previous == .inProgress, status != .inProgress else { return }
        logger.info("\(snapshot.ref.id, privacy: .public) 실행 종료 · \(status.label, privacy: .public)")
        notifier.post(
            title: "\(status.emoji) \(snapshot.ref.name)",
            body: "배포 \(status.label) · \(snapshot.ref.profile)",
            link: snapshot.ref.consoleURL
        )
    }

    private var pollInterval: Duration {
        let current = Array(snapshots.values)
        // 인증 만료 · 오프라인이면 전부 같은 이유로 실패하니 천천히 — 새로고침 버튼으로 바로 다시 볼 수 있음
        if !current.isEmpty && current.allSatisfy({ $0.failureReason != nil }) {
            return .seconds(300)
        }
        let isAnyRunning = current.contains { $0.execution?.status == .inProgress }
        let seconds = isAnyRunning ? configuration.activePollIntervalSeconds : configuration.pollIntervalSeconds
        return .seconds(max(5, seconds))
    }
}
