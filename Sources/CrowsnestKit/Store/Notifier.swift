import AppKit
import UserNotifications

/// 서명된 .app 으로 떴을 때만 UNUserNotificationCenter 를 씀 — 번들 없이 띄우면 그 자리에서 크래시남
@MainActor
final class Notifier: NSObject {
    private var usesUserNotifications: Bool

    override init() {
        usesUserNotifications = Bundle.main.bundleURL.pathExtension == "app"
        super.init()
        guard usesUserNotifications else { return }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted {
                usesUserNotifications = false
            }
        }
    }

    func post(title: String, body: String, link: URL) {
        guard usesUserNotifications else {
            postWithAppleScript(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": link.absoluteString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    /// 알림 권한을 거부했거나 번들 없이 띄웠을 때 — SwiftBar 스크립트와 같은 방식
    private func postWithAppleScript(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \(Self.quoted(body)) with title \(Self.quoted(title)) sound name \"Glass\""]
        try? process.run()
    }

    private static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
