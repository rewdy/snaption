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
                        .searchable(
                            text: $appState.libraryViewModel.searchQuery,
                            placement: .toolbar,
                            prompt: "Search notes, tags, labels"
                        )
                case .viewer:
                    ViewerView(appState: appState)
                }
            }
            .padding()
            .navigationTitle(navigationTitle)
            .navigationSubtitle(navigationSubtitle)
            .toolbar {
                if appState.route == .library {
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            appState.openProjectPicker()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Change folder")
                    }
                    
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Toggle(
                            isOn: Binding(
                                get: { appState.isPresentationModeEnabled },
                                set: { appState.setPresentationModeEnabled($0) }
                            )
                        ) {
                            Image(systemName: "airplayvideo")
                        }
                        .labelsHidden()
                        .accessibilityLabel("Presentation Mode")
                        .help(
                            appState.hasExternalDisplay
                                ? "Show the selected photo on the second display."
                                : "Connect a second display to enable presentation mode."
                        )
                        .toggleStyle(.automatic)
                        .disabled(!appState.hasExternalDisplay)
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Picker("Photo grouping", selection: $appState.libraryViewModel.groupByFolder) {
                            Text("Grouped").tag(true)
                            Text("Flat").tag(false)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()

                        Menu {
                            Button {
                                appState.libraryViewModel.sortDirection = .filenameAscending
                            } label: {
                                sortMenuLabel("Filename \u{2191}", isSelected: appState.libraryViewModel.sortDirection == .filenameAscending)
                            }

                            Button {
                                appState.libraryViewModel.sortDirection = .filenameDescending
                            } label: {
                                sortMenuLabel("Filename \u{2193}", isSelected: appState.libraryViewModel.sortDirection == .filenameDescending)
                            }

                            Button {
                                appState.libraryViewModel.sortDirection = .modifiedAscending
                            } label: {
                                sortMenuLabel("Date Modified \u{2191}", isSelected: appState.libraryViewModel.sortDirection == .modifiedAscending)
                            }

                            Button {
                                appState.libraryViewModel.sortDirection = .modifiedDescending
                            } label: {
                                sortMenuLabel("Date Modified \u{2193}", isSelected: appState.libraryViewModel.sortDirection == .modifiedDescending)
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .help("Sort options")
                        .disabled(appState.libraryViewModel.allItems.isEmpty)
                    }
                } else if appState.route == .viewer {
                    ToolbarItemGroup(placement: .navigation) {
                        Button {
                            appState.navigateToLibrary()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .keyboardShortcut("b", modifiers: [.command])
                        .help("Back to Library")
                    }

                    ToolbarItemGroup(placement: .secondaryAction) {
                        Toggle(
                            isOn: Binding(
                                get: { appState.isPresentationModeEnabled },
                                set: { appState.setPresentationModeEnabled($0) }
                            )
                        ) {
                            Image(systemName: "airplayvideo")
                        }
                        .labelsHidden()
                        .accessibilityLabel("Presentation Mode")
                        .help(
                            appState.hasExternalDisplay
                                ? "Show the selected photo on the second display."
                                : "Connect a second display to enable presentation mode."
                        )
                        .toggleStyle(.automatic)
                        .disabled(!appState.hasExternalDisplay)
                    }

                }
            }
        }
    }

    private var appName: String {
        return "Snaption"
    }
    
    private var projectName: String? {
        appState.libraryViewModel.rootURL?.lastPathComponent
    }

    private var navigationTitle: String {
        switch appState.route {
        case .start:
            return appName
        case .library:
            return projectName ?? appName
        case .viewer:
            let base = projectName ?? appName
            guard let relativePath = appState.selectedPhoto?.relativePath else {
                return base
            }

            let segments = relativePath
                .split(separator: "/")
                .map(String.init)

            guard segments.count > 1 else {
                return base
            }

            let subfolders = segments.dropLast().joined(separator: "/")
            return "\(base)/\(subfolders)"
        }
    }

    private var navigationSubtitle: String {
        if appState.route == .library {
            let count = appState.libraryViewModel.isIndexing
                ? appState.libraryViewModel.indexedCount
                : appState.libraryViewModel.allItems.count
            return "\(count) photos"
        }

        if appState.route == .viewer {
            let filename = appState.selectedPhoto?.filename ?? ""
            guard !filename.isEmpty else {
                return ""
            }
            return "\(filename) - \(appState.notesSaveState.label.lowercased())"
        }

        return ""
    }

    @ViewBuilder
    private func sortMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
