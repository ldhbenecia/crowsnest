import SwiftUI

/// 메뉴바 아이템 · 패널은 StatusItemController 가 AppKit 으로 쥐고, 여기는 앱 메뉴만 둠
/// SwiftUI App 은 장면이 하나는 있어야 해서 빈 Settings 장면에 앱 메뉴 명령을 붙임 — 설정은 우리 창으로 엶
public struct CrowsnestMenuBar: Scene {
    private let store = PipelineStore.shared

    public init() {
        // 앱이 다 뜬 다음에 메뉴바 아이템을 만듦
        DispatchQueue.main.async {
            StatusItemController.shared.install()
            // 개발 확인용 — open Crowsnest.app --args --open-settings 면 설정 창부터, --test-notification 이면 알림 하나를 띄움
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--open-settings") {
                SettingsWindow.show()
            }
            if arguments.contains("--test-notification") {
                PipelineStore.shared.postTestNotification()
            }
        }
    }

    public var body: some Scene {
        // 언어를 읽어둬야 바꿨을 때 이 body 가 다시 돌아서 앱 메뉴가 새 언어로 바뀜
        let _ = store.configuration.language
        Settings { EmptyView() }
            // 정보 · 설정 창이 떠 있는 동안만 보이는 앱 메뉴
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button(L("Crowsnest 정보", "About Crowsnest")) { AboutWindow.show() }
                }
                CommandGroup(replacing: .appSettings) {
                    Button(L("설정…", "Settings…")) { SettingsWindow.show() }
                        .keyboardShortcut(",")
                }
                CommandGroup(replacing: .newItem) {}
            }
    }
}
