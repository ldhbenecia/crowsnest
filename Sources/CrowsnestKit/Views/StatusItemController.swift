import AppKit
import SwiftUI

/// 메뉴바 아이템과 패널을 AppKit 으로 직접 쥠
/// SwiftUI MenuBarExtra 는 왼쪽 클릭을 안에서 처리해서 우클릭 메뉴 · 다시 눌러 닫기 같은 기본 동작을 맞출 수가 없었음
@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private let store = PipelineStore.shared
    private var statusItem: NSStatusItem?
    private var panel: PanelWindow?
    /// 패널 밖을 누르면 닫으려고 — 다른 앱 창 · 바탕화면 클릭은 이 앱으로 안 오니 전역으로 봄
    private var outsideClickMonitor: Any?
    /// 패널이 열린 채 아이콘을 누르면 누르는 순간 패널이 포커스를 잃어 먼저 닫히고, 떼는 순간 아이콘 동작이 와서 다시 열림
    /// 방금 닫힌 거면 그 클릭은 닫기로 보고 다시 열지 않음
    private var lastClosedAt = Date.distantPast

    func install() {
        guard statusItem == nil else { return }
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = statusItem
        observeMenuBarImage()
    }

    /// 상태가 바뀔 때마다 아이콘 이미지를 다시 그림 — 언어도 읽어서 VoiceOver 설명이 따라감
    private func observeMenuBarImage() {
        let image = withObservationTracking {
            _ = store.configuration.language
            return MenuBarImage.make(for: store.menuBarStatus)
        } onChange: {
            DispatchQueue.main.async { [weak self] in self?.observeMenuBarImage() }
        }
        statusItem?.button?.image = image
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isContextClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isContextClick {
            closePanel()
            showContextMenu()
        } else if panel?.isVisible == true {
            closePanel()
        } else if Date.now.timeIntervalSince(lastClosedAt) > 0.3 {
            openPanel()
        }
    }

    // MARK: 우클릭 메뉴

    /// 메뉴를 상태 항목에 잠깐 붙였다 떼면 눌림 표시 · 위치 · 다시 눌러 닫기를 시스템이 다른 앱과 똑같이 처리함
    private func showContextMenu() {
        guard let statusItem, let button = statusItem.button else { return }
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(L("Crowsnest 정보", "About Crowsnest")) { AboutWindow.show() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(L("Crowsnest 종료", "Quit Crowsnest"), keyEquivalent: "q") { NSApp.terminate(nil) })
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: 패널

    private func openPanel() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let panel = PanelWindow()
        // 열 때마다 새로 붙여서 onAppear 로 갱신 · 애니메이션이 다시 시작되게
        panel.setContent(LanguageScope(store: store) { PanelView(store: store) })
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: anchor)
        button.highlight(true)
        self.panel = panel

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidResignKey), name: NSWindow.didResignKeyNotification, object: panel)
    }

    /// 설정 · 정보 창을 열거나 다른 앱으로 가면 패널을 닫음 — 메뉴바 패널은 다른 데로 가면 사라지는 게 보통
    @objc private func panelDidResignKey() {
        closePanel()
    }

    func closePanel() {
        guard let panel else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: panel)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
        panel.orderOut(nil)
        // 내용을 떼야 onDisappear 가 불려서 스피너 · 시각 갱신이 멈춤
        panel.contentViewController = nil
        self.panel = nil
        lastClosedAt = .now
        statusItem?.button?.highlight(false)
    }
}

/// 메뉴바 아래에 붙는 둥근 반투명 창 — 앱을 앞으로 끌어오지 않고 키보드(검색 · Esc)는 받음
private final class PanelWindow: NSPanel {
    private static let cornerRadius: CGFloat = 14
    private static let gapBelowMenuBar: CGFloat = 4
    private var anchor = NSRect.zero

    init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    /// Esc
    override func cancelOperation(_ sender: Any?) {
        StatusItemController.shared.closePanel()
    }

    func setContent(_ content: some View) {
        let background = NSVisualEffectView()
        background.material = .menu
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Self.cornerRadius
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true

        let hosting = NSHostingController(rootView: content)
        // 내용이 커지거나 줄면 창도 따라감 — 크기가 바뀌면 windowDidResize 에서 위쪽을 메뉴바에 다시 붙임
        hosting.sizingOptions = .preferredContentSize
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        let container = NSViewController()
        container.view = background
        container.addChild(hosting)
        background.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentViewController = container
        NotificationCenter.default.addObserver(self, selector: #selector(keepAnchored), name: NSWindow.didResizeNotification, object: self)
    }

    /// 메뉴바 아이콘 왼쪽 아래에 맞추되 화면 오른쪽 밖으로 나가지 않게
    func show(below anchor: NSRect) {
        self.anchor = anchor
        layoutIfNeeded()
        keepAnchored()
        makeKeyAndOrderFront(nil)
    }

    @objc private func keepAnchored() {
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: anchor.minX, y: anchor.minY - Self.gapBelowMenuBar - frame.height)
        origin.x = min(origin.x, visible.maxX - frame.width - 8)
        origin.x = max(origin.x, visible.minX + 8)
        if frame.origin != origin {
            setFrameOrigin(origin)
        }
    }
}

/// target-action 대신 클로저로 동작을 넘기는 메뉴 항목 — 메뉴는 메인 스레드에서만 눌림
@MainActor
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("코드로만 만듦")
    }

    @objc private func runHandler() {
        handler()
    }
}
