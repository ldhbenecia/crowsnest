import AppKit

/// 메뉴바 아이콘 우클릭(또는 Control 클릭) 메뉴 — 패널을 열고 ··· 를 누르지 않아도 설정 · 정보 · 종료로 바로 감
/// SwiftUI MenuBarExtra 는 우클릭을 못 받아서, 이 앱의 상태 막대 창에 들어오는 클릭을 가로챔
@MainActor
enum StatusItemMenu {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
            let isContextClick = event.type == .rightMouseDown || event.modifierFlags.contains(.control)
            // 메뉴바 아이템을 그리는 창은 NSStatusBarWindow — 다른 창의 클릭은 그대로 흘려보냄
            guard isContextClick,
                  let window = event.window,
                  String(describing: type(of: window)).contains("NSStatusBarWindow"),
                  let contentView = window.contentView,
                  let button = statusButton(in: contentView) else { return event }
            showMenu(window: window, button: button)
            return nil
        }
    }

    /// 상태 항목에 메뉴를 잠깐 붙이고 누르면 시스템이 다른 메뉴바 앱과 똑같이 눌림 표시 · 아이콘 아래 위치로 띄워줌
    /// 버튼에 직접 highlight 를 걸면 SwiftUI 가 쥔 버튼이라 안 그려짐
    private static func showMenu(window: NSWindow, button: NSButton) {
        // statusItem 은 공개 API 가 아니라서 없을 때를 대비해 확인하고 꺼냄
        guard window.responds(to: NSSelectorFromString("statusItem")),
              let statusItem = window.value(forKey: "statusItem") as? NSStatusItem else {
            makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
            return
        }
        statusItem.menu = makeMenu()
        // 메뉴가 닫힐 때까지 돌아오지 않음 — 그다음 메뉴를 떼야 왼쪽 클릭이 다시 패널을 엶
        button.performClick(nil)
        statusItem.menu = nil
    }

    /// 상태 막대 창 안에서 아이콘을 그리는 버튼(NSStatusBarButton)
    private static func statusButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        return view.subviews.lazy.compactMap(statusButton(in:)).first
    }

    /// 언어를 바꿀 수 있어서 누를 때마다 새로 만듦
    private static func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(L("설정…", "Settings…"), keyEquivalent: ",") { SettingsWindow.show() })
        menu.addItem(ClosureMenuItem(L("Crowsnest 정보", "About Crowsnest")) { AboutWindow.show() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(L("Crowsnest 종료", "Quit Crowsnest"), keyEquivalent: "q") { NSApp.terminate(nil) })
        return menu
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
