import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.ldhbenecia.crowsnest", category: "store")

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
    private(set) var notificationsEnabled: Bool
    /// 설정 파일 · aws CLI 문제처럼 패널 맨 위에 띄울 것
    let notices: [String]

    @ObservationIgnored private let configuration: AppConfiguration
    @ObservationIgnored private let service: CodePipelineService?
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private var previousStatuses: [PipelineRef: PipelineStatus] = [:]
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

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
    }

    var orderedSnapshots: [PipelineSnapshot] {
        selection.compactMap { snapshots[$0] }
    }

    var menuBarTitle: String? {
        MenuBarTitle.make(for: orderedSnapshots)
    }

    /// Scene 이 여러 번 만들어져도 폴링은 하나만 돌게
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: self.pollInterval)
            }
        }
        Task { await reloadCatalogs() }
    }

    func refresh() async {
        guard let service, !isRefreshing else { return }
        let targets = selection
        isRefreshing = true
        let fresh = await withTaskGroup(of: PipelineSnapshot.self) { group in
            for ref in targets {
                group.addTask { await service.snapshot(of: ref) }
            }
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

    /// 패널을 열 때 — 방금 갱신했으면 다시 안 부름
    func refreshIfStale() {
        let isFresh = lastRefreshedAt.map { Date.now.timeIntervalSince($0) < 5 } ?? false
        if !isFresh {
            Task { await refresh() }
        }
    }

    func reloadCatalogs() async {
        guard let service, !isLoadingCatalogs else { return }
        isLoadingCatalogs = true
        do {
            catalogs = try await service.loadCatalogs()
            catalogError = nil
        } catch {
            catalogError = error.localizedDescription
            logger.error("프로필 목록 조회 실패 · \(error.localizedDescription, privacy: .public)")
        }
        isLoadingCatalogs = false
    }

    func toggle(_ ref: PipelineRef) {
        if let index = selection.firstIndex(of: ref) {
            selection.remove(at: index)
            snapshots[ref] = nil
            previousStatuses[ref] = nil
        } else {
            selection.append(ref)
            Task { await fetch(ref) }
        }
        Preferences.selection = selection
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        notificationsEnabled = isEnabled
        Preferences.notificationsMuted = !isEnabled
    }

    /// 새로 고른 파이프라인은 다음 주기까지 안 기다리고 바로 받아옴
    private func fetch(_ ref: PipelineRef) async {
        guard let service else { return }
        apply([await service.snapshot(of: ref)])
    }

    /// 조회하는 사이에 선택 해제된 건 버림
    private func apply(_ fresh: [PipelineSnapshot]) {
        for snapshot in fresh where selection.contains(snapshot.ref) {
            if let reason = snapshot.failureReason {
                logger.error("\(snapshot.ref.id, privacy: .public) 조회 실패 · \(reason, privacy: .public)")
            }
            notifyIfFinished(snapshot)
            snapshots[snapshot.ref] = snapshot
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
        let isAnyRunning = snapshots.values.contains { $0.execution?.status == .inProgress }
        let seconds = isAnyRunning ? configuration.activePollIntervalSeconds : configuration.pollIntervalSeconds
        return .seconds(max(5, seconds))
    }
}
