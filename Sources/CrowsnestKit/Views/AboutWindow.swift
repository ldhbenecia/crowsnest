import AppKit
import SwiftUI

/// 정보 창 — 메뉴바 앱이라 평소엔 Dock 에 없고, 이 창이 떠 있는 동안만 Dock · 앱 메뉴를 보여줌
@MainActor
public final class AboutWindow: NSObject, NSWindowDelegate {
    private static let shared = AboutWindow()

    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.title = "Crowsnest 정보"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView())
        window.delegate = self
        window.center()
        return window
    }()

    public static func show() {
        NSApp.setActivationPolicy(.regular)
        // 정책을 바꾼 직후 바로 활성화하면 창만 뜨고 포커스 · 앱 메뉴가 안 넘어올 때가 있어서 한 박자 늦춤
        DispatchQueue.main.async {
            NSApp.activate()
            shared.window.makeKeyAndOrderFront(nil)
        }
    }

    /// 창을 닫으면 다시 메뉴바 전용으로
    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Info.plist 에 빌드 스크립트가 넣어둔 값 — swift run 으로 띄우면 비어 있음
struct BuildInfo {
    let version: String?
    let commit: String?
    let buildDate: String?

    static let current: BuildInfo = {
        let info = Bundle.main.infoDictionary ?? [:]
        return BuildInfo(
            version: info["CFBundleShortVersionString"] as? String,
            commit: info["CrowsnestCommit"] as? String,
            buildDate: info["CrowsnestBuildDate"] as? String
        )
    }()

    static let repositoryURL = URL(string: "https://github.com/ldhbenecia/crowsnest")!
    static let releasesURL = URL(string: "https://github.com/ldhbenecia/crowsnest/releases")!
}

private struct AboutView: View {
    private let info = BuildInfo.current

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .padding(.top, 28)
            Text("Crowsnest")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 10)
            Text("AWS CodePipeline 배포를 메뉴바에서")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 3)

            VStack(spacing: 2) {
                Text(versionLine)
                if let buildDate = info.buildDate {
                    Text("빌드 \(buildDate)")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .textSelection(.enabled)
            .padding(.top, 14)

            HStack(spacing: 8) {
                Button("GitHub") { NSWorkspace.shared.open(BuildInfo.repositoryURL) }
                Button("릴리스 노트") { NSWorkspace.shared.open(BuildInfo.releasesURL) }
            }
            .controlSize(.large)
            .pointingHandCursor()
            .padding(.top, 20)

            Text("© 2026 ldhbenecia · MIT License")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 18)
                .padding(.bottom, 20)
        }
        .frame(width: 300)
    }

    private var versionLine: String {
        guard let version = info.version else { return "개발 빌드" }
        return info.commit.map { "버전 \(version) (\($0))" } ?? "버전 \(version)"
    }
}
