import AppKit
import SwiftUI

/// 정보 · 설정 같은 일반 창 — 메뉴바 앱이라 평소엔 Dock 에 없고, 이런 창이 하나라도 떠 있는 동안만 Dock · 앱 메뉴를 보여줌
@MainActor
final class AppWindow: NSObject, NSWindowDelegate {
    private static var openWindows: Set<ObjectIdentifier> = []

    private let window: NSWindow

    convenience init(title: String, hidesTitleBar: Bool, content: some View) {
        self.init(title: title, hidesTitleBar: hidesTitleBar, contentViewController: NSHostingController(rootView: content))
    }

    init(title: String, hidesTitleBar: Bool, contentViewController: NSViewController) {
        window = NSWindow(contentViewController: contentViewController)
        window.styleMask = hidesTitleBar ? [.titled, .closable, .fullSizeContentView] : [.titled, .closable]
        super.init()
        window.title = title
        if hidesTitleBar {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func show() {
        Self.openWindows.insert(ObjectIdentifier(window))
        NSApp.setActivationPolicy(.regular)
        // 정책을 바꾼 직후 바로 활성화하면 창만 뜨고 포커스 · 앱 메뉴가 안 넘어올 때가 있어서 한 박자 늦춤
        DispatchQueue.main.async { [window] in
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            // macOS 14 부터는 활성화 요청을 시스템이 무시할 수 있어서(메뉴바 패널에서 열 때 특히) 다른 앱 창 뒤에 뜸 — 창을 직접 맨 앞으로
            window.orderFrontRegardless()
        }
    }

    /// 마지막 창이 닫히면 다시 메뉴바 전용으로
    func windowWillClose(_ notification: Notification) {
        Self.openWindows.remove(ObjectIdentifier(window))
        if Self.openWindows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

@MainActor
public enum AboutWindow {
    private static let window = AppWindow(title: "Crowsnest 정보", hidesTitleBar: true, content: AboutView())

    public static func show() {
        window.show()
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
