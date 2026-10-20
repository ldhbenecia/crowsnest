import SwiftUI

public struct CrowsnestMenuBar: Scene {
    private let store = PipelineStore.shared

    public init() {
        PipelineStore.shared.start()
    }

    public var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let store: PipelineStore

    var body: some View {
        if let title = store.menuBarTitle {
            Text(title)
        } else {
            Image(systemName: "binoculars.fill")
        }
    }
}
