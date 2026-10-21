import AppKit

/// 설정 · 정보 창이 떠 있는 동안만 Dock 에 보이는데, 거기서 종료를 눌러도 메뉴바 앱까지 꺼지면 안 됨
/// Dock 이 보낸 종료만 창을 닫는 것으로 바꾸고, 앱 메뉴 · 패널의 종료나 로그아웃 · 재시동은 그대로 끔
@MainActor
public final class CrowsnestAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.isQuitRequestFromDock else { return .terminateNow }
        AppWindow.closeAll()
        return .terminateCancel
    }

    /// Dock 의 종료는 Dock 프로세스가 보낸 quit Apple Event 로 옴 — 로그아웃은 loginwindow 가 보내서 여기 안 걸림
    private static var isQuitRequestFromDock: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == kCoreEventClass, event.eventID == kAEQuitApplication,
              let senderPID = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value
        else { return false }
        return NSRunningApplication(processIdentifier: senderPID)?.bundleIdentifier == "com.apple.dock"
    }
}
