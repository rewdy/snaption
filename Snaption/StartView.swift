import SwiftUI

struct StartView: View {
    @ObservedObject var appState: AppState
    @State private var showingClearRecentsConfirmation = false

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

            if !appState.recentProjectURLs.isEmpty {
                VStack(spacing: 0) {
                    Text("Recent projects")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)

                    ForEach(Array(appState.recentProjectURLs.enumerated()), id: \.element.path) { index, url in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button("Open") {
                                appState.reopenRecentProject(url)
                            }
                            .buttonStyle(.link)
                        }
                        .padding(.vertical, 8)
                        .help(url.path)

                        if index < appState.recentProjectURLs.count - 1 {
                            Divider()
                        }
                    }

                    Button("Clear recent") {
                        showingClearRecentsConfirmation = true
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .padding(.top, 14)
                }
                .frame(width: 380)
                .padding(.top, 12)
            }

            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .confirmationDialog(
            "Clear recent projects?",
            isPresented: $showingClearRecentsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear recent", role: .destructive) {
                appState.clearRecentProjects()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the recent project list from this app.")
        }
    }
}
