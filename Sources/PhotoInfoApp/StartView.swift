import SwiftUI

struct StartView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PhotoInfo MVP")
                .font(.largeTitle)
                .bold()

            Text("Open a root folder to start a project. Milestone 0 wires app state and placeholder navigation.")
                .foregroundStyle(.secondary)

            Button("Open Project Folder") {
                appState.openProjectPicker()
            }
            .buttonStyle(.borderedProminent)

            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
