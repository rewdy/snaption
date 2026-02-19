import SwiftUI

struct ViewerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Viewer Placeholder")
                .font(.title2)
                .bold()

            Text("Milestone 2 will implement image rendering and filename-order next/previous navigation.")
                .foregroundStyle(.secondary)

            Button("Back to Library") {
                appState.navigateToLibrary()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
