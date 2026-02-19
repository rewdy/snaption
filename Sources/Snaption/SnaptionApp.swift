import SwiftUI

@main
struct SnaptionApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}
