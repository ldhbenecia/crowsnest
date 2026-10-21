import CrowsnestKit
import SwiftUI

@main
struct CrowsnestApp: App {
    @NSApplicationDelegateAdaptor(CrowsnestAppDelegate.self) private var appDelegate

    var body: some Scene {
        CrowsnestMenuBar()
    }
}
