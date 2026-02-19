import SwiftUI

struct LibraryView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library Placeholder")
                .font(.title2)
                .bold()

            if let projectRootURL = appState.projectRootURL {
                Text("Project root: \(projectRootURL.path)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("No project selected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Viewer Placeholder") {
                    appState.openViewerPlaceholder()
                }
                .buttonStyle(.bordered)

                Button("Choose Different Folder") {
                    appState.openProjectPicker()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
