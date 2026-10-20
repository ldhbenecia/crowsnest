import AppKit

/// 메뉴바 아이콘 우클릭(또는 Control 클릭) 메뉴 — 왼쪽 클릭은 패널, 우클릭은 정보 · 종료만
/// SwiftUI MenuBarExtra 는 우클릭을 못 받아서, 이 앱의 상태 막대 창에 들어오는 클릭을 가로챔
@MainActor
enum StatusItemMenu {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.rightMouseDown, .rightMouseUp, .leftMouseDown, .leftMouseUp]
        monitor = NSEvent.addLocalMonitorForEvents(matching: events) { event in
            // 메뉴바 아이템을 그리는 창은 NSStatusBarWindow — 다른 창의 클릭은 그대로 흘려보냄
            guard let window = event.window,
                  String(describing: type(of: window)).contains("NSStatusBarWindow"),
                  let contentView = window.contentView,
                  let button = statusButton(in: contentView) else { return event }
            let isContextClick = event.type == .rightMouseDown || event.type == .rightMouseUp
                || event.modifierFlags.contains(.control)
            guard isContextClick else { return event }
            if event.type == .rightMouseDown || event.type == .leftMouseDown {
                showMenu(in: contentView, below: button)
            }
            // 떼는 이벤트가 SwiftUI 버튼에 닿으면 클릭으로 보고 패널을 열어서 같이 삼킴
            return nil
        }
    }

    /// 메뉴는 아이콘 바로 아래에 띄우고, 떠 있는 동안 다른 메뉴바 앱처럼 아이콘 뒤에 눌림 배경을 깔아둠
    /// 상태 항목에 메뉴를 맡기면 SwiftUI 가 패널까지 같이 열고, 버튼 highlight 는 SwiftUI 가 쥔 버튼이라 안 그려져서 직접 그림
    private static func showMenu(in contentView: NSView, below button: NSButton) {
        let pill = PressedBackgroundView(frame: contentView.bounds.insetBy(dx: 0, dy: 3.5))
        contentView.addSubview(pill, positioned: .below, relativeTo: nil)
        defer { pill.removeFromSuperview() }
        // 버튼은 뒤집힌 좌표라 maxY 가 아래쪽 — 메뉴가 닫힐 때까지 돌아오지 않음
        makeMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    /// 상태 막대 창 안에서 아이콘을 그리는 버튼(NSStatusBarButton)
    private static func statusButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        return view.subviews.lazy.compactMap(statusButton(in:)).first
    }

    /// 언어를 바꿀 수 있어서 누를 때마다 새로 만듦
    private static func makeMenu() -> NSMenu {
        let menu = NSMenu()
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

/// 메뉴바 아이템이 눌렸을 때의 알약 모양 배경 — 메뉴바 글자색에 맞춰 옅게 깔아서 다크 · 라이트 둘 다 자연스러움
private final class PressedBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        layer?.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("코드로만 만듦")
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.16).cgColor
        }
    }

    override var wantsUpdateLayer: Bool { true }
}
