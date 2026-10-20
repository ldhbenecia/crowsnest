import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CrowsnestKit

// README 스크린샷 — 실제 뷰를 가짜 데이터로 화면 밖 창에 그려서 PNG 로 저장
// script/screenshots.sh 가 CROWSNEST_SCREENSHOT_DIRECTORY 를 넘길 때만 돔

private let outputDirectory = ProcessInfo.processInfo.environment["CROWSNEST_SCREENSHOT_DIRECTORY"]

@MainActor
@Suite(.enabled(if: outputDirectory != nil))
struct ScreenshotTests {
    private let now = Date.now
    private let directory = URL(fileURLWithPath: outputDirectory ?? "")

    init() {
        // README 가 영어라 스크린샷도 영어로 — 이 묶음은 screenshots.sh 로 따로만 돌아서 다른 테스트와 안 겹침
        Localization.apply(.english)
    }

    @Test func 패널() throws {
        for (scheme, suffix) in [(ColorScheme.dark, "dark"), (.light, "light")] {
            let store = PipelineStore(previewSnapshots: SampleData.snapshots(now: now), refreshedAt: now)
            try render(PanelChrome { PanelView(store: store) }, scheme: scheme, name: "panel-\(suffix)")
        }
    }

    @Test func 파이프라인_선택() throws {
        let store = PipelineStore(
            previewSnapshots: Array(SampleData.snapshots(now: now).prefix(3)),
            catalogs: SampleData.catalogs,
            refreshedAt: now
        )
        try render(PanelChrome { PipelinePicker(store: store) {} }, scheme: .dark, name: "picker")
    }

    @Test func 설정() throws {
        let store = PipelineStore(previewSnapshots: [], catalogs: SampleData.catalogs, refreshedAt: now)
        try render(PanelChrome { GeneralSettings(store: store).frame(width: SettingsWindow.width) }, scheme: .dark, name: "settings-general")
        try render(PanelChrome { NotificationSettings(store: store).frame(width: SettingsWindow.width) }, scheme: .dark, name: "settings-notifications")
        try render(PanelChrome { AWSSettings(store: store).frame(width: SettingsWindow.width) }, scheme: .dark, name: "settings-aws")
    }

    @Test func 메뉴바() throws {
        let snapshots = Dictionary(uniqueKeysWithValues: SampleData.snapshots(now: now).map { ($0.ref.name, $0) })
        func status(_ names: String...) -> MenuBarStatus {
            MenuBarStatus.make(for: names.compactMap { snapshots[$0] })
        }
        let states: [MenuBarStatus] = [
            status("storefront-api-prod", "search-indexer-prod"),
            status("admin-console-prod"),
            status("billing-worker-staging"),
            .idle,
        ]
        let strips = VStack(alignment: .trailing, spacing: 10) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, status in
                HStack(spacing: 16) {
                    Image(nsImage: MenuBarImage.make(for: status)).renderingMode(.template)
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75percent")
                    Text("Tue 10:42").font(.system(size: 13))
                }
                .padding(.horizontal, 14)
                .frame(width: 420, height: 26, alignment: .trailing)
                .background(.bar)
            }
        }
        .padding(16)
        for (scheme, suffix) in [(ColorScheme.dark, "dark"), (.light, "light")] {
            try render(strips, scheme: scheme, name: "menubar-\(suffix)")
        }
    }

    /// 화면 밖 창에 띄워서 레이아웃 · onAppear · 높이 측정이 실제처럼 돌고 나서 찍음
    private func render(_ view: some View, scheme: ColorScheme, name: String) throws {
        let hostingView = NSHostingView(rootView: view.environment(\.colorScheme, scheme))
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 100, height: 100),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hostingView
        window.orderFrontRegardless()
        for _ in 0..<6 {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.15))
            window.setContentSize(hostingView.fittingSize)
            hostingView.layoutSubtreeIfNeeded()
        }
        // 화면 배율(2x)보다 촘촘하게 3x 로 — GitHub 가 크기를 맞추며 줄여도 글자가 안 뭉개지게
        let scale: CGFloat = 3
        let bounds = hostingView.bounds
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width * scale), pixelsHigh: Int(bounds.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        bitmap.size = bounds.size
        hostingView.cacheDisplay(in: bounds, to: bitmap)
        window.orderOut(nil)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: directory.appending(path: "\(name).png"))
    }
}

/// 메뉴바 패널처럼 둥근 모서리 · 테두리 · 그림자 — 실제 패널은 시스템이 그려줘서 캡처할 때만 흉내 냄
private struct PanelChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
            .padding(28)
    }
}

/// 실제 회사 · 계정과 무관한 예시 이름만
private enum SampleData {
    static func snapshots(now: Date) -> [PipelineSnapshot] {
        [
            snapshot("storefront-api-prod", profile: "production", status: .inProgress, minutesAgo: 3, commit: ("4f1c2a9", "feat: cache product search results"), stages: [
                stage("Source", .succeeded, [action("Source", .succeeded)]),
                stage("Build", .inProgress, [action("Build-api", .inProgress, log: true), action("Build-worker", .succeeded)]),
                stage("Deploy", .succeeded, current: false, [action("Deploy", .succeeded)]),
            ], now: now),
            snapshot("admin-console-prod", profile: "production", status: .inProgress, minutesAgo: 12, commit: ("b83e017", "fix: keep filters after pagination"), stages: [
                stage("Source", .succeeded, [action("Source", .succeeded)]),
                stage("Build", .succeeded, [action("Build", .succeeded)]),
                stage("Approve", .inProgress, [action("Approve", .inProgress, awaiting: true)]),
                stage("Deploy", nil, [action("Deploy", nil)]),
            ], now: now),
            snapshot("billing-worker-staging", profile: "staging", status: .failed, minutesAgo: 41, commit: ("e02d7f4", "chore: bump runtime to node 22"), stages: [
                stage("Source", .succeeded, [action("Source", .succeeded)]),
                stage("Build", .failed, [action(
                    "Build", .failed,
                    error: "Build terminated with state: FAILED. Phase: BUILD, Code: COMMAND_EXECUTION_ERROR, Message: npm test exited with 1",
                    log: true
                )]),
                stage("Deploy", .succeeded, current: false, [action("Deploy", .succeeded)]),
            ], now: now),
            snapshot("marketing-site-prod", profile: "production", status: .failed, minutesAgo: 95, commit: ("7a9b3c1", "feat: spring campaign banner"), stages: [
                stage("Source", .succeeded, [action("Source", .succeeded)]),
                stage("Approve", .failed, [action("Approve", .failed, decidedBy: "jane.doe")]),
                stage("Deploy", .succeeded, current: false, [action("Deploy", .succeeded)]),
            ], now: now),
            snapshot("search-indexer-prod", profile: "production", status: .succeeded, minutesAgo: 60 * 5, commit: ("19d0e6b", "perf: batch index writes"), stages: [
                stage("Source", .succeeded, [action("Source", .succeeded)]),
                stage("Build", .succeeded, [action("Build", .succeeded)]),
                stage("Deploy", .succeeded, [action("Deploy", .succeeded)]),
            ], now: now),
        ]
    }

    static let catalogs = [
        ProfileCatalog(
            profile: "production", region: "us-east-1",
            pipelines: ["admin-console-prod", "marketing-site-prod", "search-indexer-prod", "storefront-api-prod"],
            loadError: nil
        ),
        ProfileCatalog(profile: "staging", region: "us-west-2", pipelines: ["billing-worker-staging", "storefront-api-staging"], loadError: nil),
        ProfileCatalog(profile: "sandbox", region: "eu-west-1", pipelines: [], loadError: "인증 만료 · 터미널에서 aws sso login --profile sandbox"),
    ]

    private static func snapshot(
        _ name: String, profile: String, status: PipelineStatus, minutesAgo: Double,
        commit: (String, String), stages: [StageSnapshot], now: Date
    ) -> PipelineSnapshot {
        PipelineSnapshot(
            ref: PipelineRef(profile: profile, region: "us-east-1", name: name),
            execution: ExecutionSummary(
                id: "current", status: status, startedAt: nil, updatedAt: now.addingTimeInterval(-minutesAgo * 60),
                revision: SourceRevision(shortId: commit.0, message: commit.1)
            ),
            stages: stages,
            failureReason: nil
        )
    }

    private static func stage(_ name: String, _ status: PipelineStatus?, current: Bool = true, _ actions: [ActionSnapshot]) -> StageSnapshot {
        StageSnapshot(name: name, status: status, executionId: current ? "current" : "previous", belongsToLatestExecution: current, actions: actions)
    }

    private static func action(
        _ name: String, _ status: PipelineStatus?, error: String? = nil, log: Bool = false,
        decidedBy: String? = nil, awaiting: Bool = false
    ) -> ActionSnapshot {
        ActionSnapshot(
            name: name, status: status, summary: nil, errorMessage: error,
            externalURL: log ? URL(string: "https://console.aws.amazon.com/codesuite/codebuild") : nil,
            decidedBy: decidedBy, isAwaitingApproval: awaiting
        )
    }
}
