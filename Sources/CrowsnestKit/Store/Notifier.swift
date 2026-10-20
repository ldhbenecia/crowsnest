import AppKit
import UserNotifications

/// .app 으로 떴으면 UNUserNotificationCenter — 번들 없이 `swift run` 으로 띄우면 그 자리에서 크래시나서 osascript 로 대신함
@MainActor
final class Notifier: NSObject {
    private let isBundled = Bundle.main.bundleIdentifier != nil

    override init() {
        super.init()
        guard isBundled else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 권한을 거부했으면 시스템이 안 띄움 — 사용자 선택이라 우회하지 않음
    func post(title: String, body: String, link: URL, playsSound: Bool) {
        guard isBundled else {
            postWithAppleScript(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = playsSound ? .default : nil
        content.userInfo = ["url": link.absoluteString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    /// 문자열을 스크립트에 끼워 넣지 않고 인자로 넘겨서 이스케이프가 필요 없음
    private func postWithAppleScript(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "on run argv",
            "-e", "display notification (item 2 of argv) with title (item 1 of argv) sound name \"Glass\"",
            "-e", "end run",
            title, body,
        ]
        try? process.run()
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// 메뉴바 앱은 늘 활성 상태라 이걸 안 열어두면 배너가 안 뜸
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// 알림을 누르면 해당 파이프라인 콘솔로 감
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let link = response.notification.request.content.userInfo["url"] as? String, let url = URL(string: link) {
            Task { @MainActor in NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
