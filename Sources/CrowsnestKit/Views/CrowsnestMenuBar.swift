import SwiftUI

public struct CrowsnestMenuBar: Scene {
    private let store = PipelineStore.shared

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuBarLabel(status: store.menuBarStatus)
        }
        .menuBarExtraStyle(.window)
        // 정보 창이 떠 있는 동안만 보이는 앱 메뉴
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Crowsnest 정보") { AboutWindow.show() }
            }
            CommandGroup(replacing: .appSettings) {
                Button("설정 파일 열기…") { NSWorkspace.shared.open(AppConfiguration.fileURL) }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct MenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        Image(nsImage: MenuBarImage.make(for: status))
    }
}
