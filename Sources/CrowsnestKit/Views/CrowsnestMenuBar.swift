import SwiftUI

public struct CrowsnestMenuBar: Scene {
    private let store = PipelineStore.shared

    public init() {
        StatusItemMenu.install()
    }

    public var body: some Scene {
        // 언어를 읽어둬야 바꿨을 때 이 body 가 다시 돌아서 앱 메뉴 · 메뉴바 설명이 새 언어로 바뀜
        let language = store.configuration.language
        MenuBarExtra {
            LanguageScope(store: store) { PanelView(store: store) }
        } label: {
            MenuBarLabel(status: store.menuBarStatus, language: language)
        }
        .menuBarExtraStyle(.window)
        // 정보 창이 떠 있는 동안만 보이는 앱 메뉴
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

struct MenuBarLabel: View {
    let status: MenuBarStatus
    /// 값은 안 쓰고, 바뀌면 다시 그리게만 함
    var language = AppLanguage.system

    var body: some View {
        Image(nsImage: MenuBarImage.make(for: status))
    }
}
