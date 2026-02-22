import SwiftUI

struct RootView: View {
    @ObservedObject var appState: AppState
    @State private var isRecordingPulseOn = false

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

    private var recordingPulseColor: Color {
        isRecordingPulseOn ? .red : .red.opacity(0.7)
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
                appState.navigateToStart()
            } label: {
                Image(systemName: "folder")
            }
            .help("Back to Start")
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            if appState.isPresentationModeEnabled {
                Button("End slideshow") {
                    appState.setPresentationModeEnabled(false)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.76, green: 0.51, blue: 0.96))
                .foregroundStyle(.white)
            }

            presentationMenu

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
            if appState.isPresentationModeEnabled {
                Button("End slideshow") {
                    appState.setPresentationModeEnabled(false)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.76, green: 0.51, blue: 0.96))
                .foregroundStyle(.white)
            }
            
            presentationMenu

            Button {
                appState.toggleAudioRecording()
            } label: {
                if appState.isAudioRecordingBlinking {
                    ZStack {
                        Circle()
                            .fill(.green)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 8, weight: .bold))
                            
                    }
                    .frame(width: 22, height: 22)
                } else if appState.isAudioRecordingEnabled {
                    ZStack {
                        Circle()
                            .fill(recordingPulseColor)
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 10))
                        
                    }
                    .frame(width: 22, height: 22)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecordingPulseOn)
                } else {
                    Image(systemName: "mic")
                        .foregroundStyle(.primary)
                }
            }
            .help(appState.isAudioRecordingEnabled ? "Stop recording" : "Start recording")
            .onAppear {
                if appState.isAudioRecordingEnabled {
                    isRecordingPulseOn.toggle()
                } else {
                    isRecordingPulseOn = false
                }
            }
            .onChange(of: appState.isAudioRecordingEnabled) { _, isEnabled in
                if isEnabled {
                    isRecordingPulseOn.toggle()
                } else {
                    isRecordingPulseOn = false
                }
            }
            .sheet(isPresented: $appState.isAudioStartDialogPresented) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Start Recording")
                        .font(.headline)
                    Text("Choose what to save for this recording session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "Save original recording files",
                        isOn: Binding(
                            get: { appState.shouldSaveRecordingFiles },
                            set: { appState.setSaveRecordingFiles($0) }
                        )
                    )
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

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(
                            "Auto-record enabled",
                            isOn: Binding(
                                get: { appState.isAutoRecordingEnabled },
                                set: { appState.setAutoRecordingEnabled($0) }
                            )
                        )
                        Text("Recordings start and stop as you move between photos automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

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

    private var presentationMenu: some View {
        Menu {
            if appState.availablePresentationDisplays.isEmpty {
                Button("No displays found") {}
                    .disabled(true)
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
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.stack")
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .labelsHidden()
        .accessibilityLabel("Presentation Mode")
        .help(
            appState.hasExternalDisplay
                ? "Show the selected photo on the selected display."
                : "Connect a second display to enable presentation mode."
        )
        .popover(isPresented: $appState.isAirPlayPickerPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AirPlay Devices")
                    .font(.headline)
                AirPlayRoutePickerView()
            }
            .padding()
            .frame(width: 240)
        }
    }
}
