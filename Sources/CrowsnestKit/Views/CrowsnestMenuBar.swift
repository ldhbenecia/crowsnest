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
    }
}

struct MenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        Image(nsImage: MenuBarImage.make(for: status))
    }
}
