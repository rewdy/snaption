import SwiftUI

struct RootView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                switch appState.route {
                case .start:
                    StartView(appState: appState)
                case .library:
                    LibraryView(appState: appState)
                case .viewer:
                    ViewerView(appState: appState)
                }
            }
            .padding()
            .navigationTitle("Snaption")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Start") {
                        appState.navigateToStart()
                    }
                    .disabled(appState.route == .start)

                    Button("Library") {
                        appState.navigateToLibrary()
                    }
                    .disabled(appState.route == .library || appState.projectRootURL == nil)
                }
            }
        }
    }
}
