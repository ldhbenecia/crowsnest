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
                  let view = window.contentView else { return event }
            NSMenu.popUpContextMenu(makeMenu(), with: event, for: view)
            return nil
        }
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
