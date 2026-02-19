import SwiftUI

@main
struct SnaptionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}
