import SwiftUI

struct StartView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Open a root folder to start a project.",
                systemImage: "photo.on.rectangle.angled"
            )

            Button("Open Project Folder") {
                appState.openProjectPicker()
            }
            .buttonStyle(.borderedProminent)

            if let lastProjectURL = appState.lastProjectURL {
                VStack(spacing: 4) {
                    Text("Last project opened:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        appState.reopenLastProject()
                    } label: {
                        Text(lastProjectURL.path)
                            .font(.footnote)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.link)
                    .frame(maxWidth: 520)
                }
            }

            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
