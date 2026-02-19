import AppKit
import SwiftUI

struct ViewerView: View {
    @ObservedObject var appState: AppState
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button("Back to Library") {
                    appState.navigateToLibrary()
                }
                .buttonStyle(.bordered)

                Button("Previous") {
                    appState.goToPreviousPhoto()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canGoToPreviousPhoto)

                Button("Next") {
                    appState.goToNextPhoto()
                }
                .buttonStyle(.bordered)
                .disabled(!appState.canGoToNextPhoto)

                Spacer()

                Text(appState.notesSaveState.label)
                    .font(.footnote)
                    .foregroundStyle(saveStateColor)
            }

            if let selectedPhoto = appState.selectedPhoto {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPhoto.filename)
                            .font(.title2)
                            .bold()

                        Text(selectedPhoto.relativePath)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.12))

                            if let image {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            } else {
                                ProgressView("Loading image...")
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        TextEditor(text: Binding(
                            get: { appState.notesText },
                            set: { appState.updateNotesDraft($0) }
                        ))
                        .font(.body.monospaced())
                        .frame(minWidth: 300, idealWidth: 360)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )

                        if let notesStatusMessage = appState.notesStatusMessage {
                            Text(notesStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No photo selected",
                    systemImage: "photo",
                    description: Text("Select a photo from the library.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: appState.selectedPhotoID) {
            guard let selectedPhoto = appState.selectedPhoto else {
                image = nil
                return
            }

            image = NSImage(contentsOf: selectedPhoto.imageURL)
        }
    }

    private var saveStateColor: Color {
        switch appState.notesSaveState {
        case .clean:
            return .secondary
        case .dirty:
            return .orange
        case .saving:
            return .secondary
        case .error:
            return .red
        }
    }
}
