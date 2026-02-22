import SwiftUI

struct SnaptionCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Project Folder...") {
                appState.openProjectPicker()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Menu("Open Recent") {
                if appState.recentProjectURLs.isEmpty {
                    Text("No Recent Projects")
                } else {
                    ForEach(appState.recentProjectURLs, id: \.path) { url in
                        Button(url.lastPathComponent) {
                            appState.reopenRecentProject(url)
                        }
                        .help(url.path)
                    }
                }
            }
        }

        CommandGroup(after: .toolbar) {
            Menu("Start Presentation") {
                if appState.availablePresentationDisplays.isEmpty {
                    Text("No displays found")
                } else {
                    ForEach(appState.availablePresentationDisplays) { display in
                        Button {
                            appState.selectPresentationDisplay(display.id)
                        } label: {
                            if display.id == appState.presentationDisplayID {
                                Label(display.name, systemImage: "checkmark")
                            } else {
                                Text(display.name)
                            }
                        }
                    }
                }

                Divider()

                Button("AirPlay Devices...") {
                    appState.isAirPlayPickerPresented = true
                }
            }

            Divider()

            Button {
                appState.libraryViewModel.groupByFolder = true
            } label: {
                if appState.libraryViewModel.groupByFolder {
                    Label("Grouped", systemImage: "checkmark")
                } else {
                    Text("Grouped")
                }
            }

            Button {
                appState.libraryViewModel.groupByFolder = false
            } label: {
                if appState.libraryViewModel.groupByFolder {
                    Text("Flat")
                } else {
                    Label("Flat", systemImage: "checkmark")
                }
            }

            Divider()
        }
    }
}
