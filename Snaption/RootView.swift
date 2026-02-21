import SwiftUI

struct RootView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationStack {
            routeContent
            .padding()
            .navigationTitle(navigationTitle)
            .navigationSubtitle(navigationSubtitle)
            .toolbar {
                toolbarContent
            }
        }
        .confirmationDialog(
            "Enable Face Features for this folder?",
            isPresented: $appState.isFaceOptInPromptPresented,
            titleVisibility: .visible
        ) {
            Button("Enable Face Features") {
                appState.enableFaceFeatures()
            }
            Button("Not Now", role: .cancel) {
                appState.declineFaceFeatures()
            }
        } message: {
            Text("Face detection runs locally and can be disabled at any time.")
        }
        .confirmationDialog(
            "Disable Face Features?",
            isPresented: $appState.isFaceDisableDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Disable and Keep Data") {
                appState.disableFaceFeatures(purgeData: false)
            }
            Button("Disable and Purge Data", role: .destructive) {
                appState.disableFaceFeatures(purgeData: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keeping data allows faster re-enable later.")
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
        case .faceGallery:
            return projectName ?? "Face Gallery"
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

    private var audioRecordingColor: Color {
        if appState.isAudioRecordingBlinking {
            return .red.opacity(0.2)
        }
        return appState.isAudioRecordingEnabled ? .red : .primary
    }

    @ViewBuilder
    private func sortMenuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch appState.route {
        case .start:
            StartView(appState: appState)
        case .library:
            LibraryView(appState: appState)
                .searchable(
                    text: $appState.libraryViewModel.searchQuery,
                    placement: .toolbar,
                    prompt: "Search filenames, notes, tags, labels"
                )
        case .viewer:
            ViewerView(appState: appState)
        case .faceGallery:
            faceGalleryContent
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch appState.route {
        case .library:
            libraryToolbar
        case .viewer:
            viewerToolbar
        case .faceGallery:
            faceGalleryToolbar
        case .start:
            ToolbarItemGroup(placement: .automatic) {}
        }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
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

            if appState.faceFeaturesEnabled {
                Button {
                    appState.openFaceGallery()
                } label: {
                    Image(systemName: "person.crop.square")
                }
                .help("Face Gallery")
            }
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

            Menu {
                if appState.faceFeaturesEnabled {
                    Button("Disable Face Features") {
                        appState.requestDisableFaceFeatures()
                    }
                } else {
                    Button("Enable Face Features") {
                        appState.enableFaceFeatures()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .help("More options")
        }
    }

    @ToolbarContentBuilder
    private var viewerToolbar: some ToolbarContent {
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

            Button {
                appState.toggleAudioRecording()
            } label: {
                Image(systemName: appState.isAudioRecordingEnabled ? "mic.fill" : "mic")
                    .foregroundStyle(audioRecordingColor)
            }
            .help(appState.isAudioRecordingEnabled ? "Stop recording" : "Start recording")
            .sheet(isPresented: $appState.isAudioStartDialogPresented) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Start Recording")
                        .font(.headline)
                    Text("Choose what to save for this recording session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle("Save original recording files", isOn: $appState.shouldSaveRecordingFiles)
                    Toggle(
                        "Update note with recording text",
                        isOn: Binding(
                            get: { appState.shouldAppendRecordingText },
                            set: { appState.setAppendRecordingText($0) }
                        )
                    )
                    .disabled(!appState.isAudioTranscriptionAvailable)
                    Toggle(
                        "Save recording summaries to notes",
                        isOn: Binding(
                            get: { appState.shouldAppendRecordingSummary },
                            set: { appState.setAppendRecordingSummary($0) }
                        )
                    )
                    .disabled(!appState.isAudioSummaryAvailable || !appState.shouldAppendRecordingText)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            appState.cancelStartAudioRecording()
                        }
                        Button("Start Recording") {
                            appState.confirmStartAudioRecording()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 360)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("Show Data File in Finder") {
                    appState.revealSelectedSidecarInFinder()
                }
                .disabled(!appState.selectedSidecarExists)

                Divider()

                if appState.faceFeaturesEnabled {
                    Button("Disable Face Features") {
                        appState.requestDisableFaceFeatures()
                    }
                } else {
                    Button("Enable Face Features") {
                        appState.enableFaceFeatures()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .help("More options")
        }
    }

    @ToolbarContentBuilder
    private var faceGalleryToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                appState.navigateToLibrary()
            } label: {
                Image(systemName: "chevron.left")
            }
            .keyboardShortcut("b", modifiers: [.command])
            .help("Back to Library")
        }
    }

    @ViewBuilder
    private var faceGalleryContent: some View {
        if let storeURL = appState.faceIndexStoreURL(), appState.faceFeaturesEnabled {
            FacesGalleryView(storeURL: storeURL)
        } else if !appState.faceFeaturesEnabled {
            ContentUnavailableView(
                "Face Features Disabled",
                systemImage: "person.crop.square",
                description: Text("Enable Face Features to view the gallery.")
            )
        } else {
            ContentUnavailableView(
                "No project open",
                systemImage: "folder",
                description: Text("Open a project to view faces.")
            )
        }
    }
}
