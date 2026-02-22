import SwiftUI

@main
struct SnaptionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var uiState = AppUIState()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState, uiState: uiState)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands {
            SnaptionCommands(appState: appState, uiState: uiState)
        }
    }
}
