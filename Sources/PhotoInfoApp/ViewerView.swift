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
            }

            if let selectedPhoto = appState.selectedPhoto {
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
}
