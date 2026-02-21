import AppKit
import Combine
import Foundation
import Speech

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .start
    @Published var projectRootURL: URL?
    @Published private(set) var lastProjectURL: URL?
    @Published var statusMessage: String?
    @Published var libraryViewModel = LibraryViewModel() {
        didSet {
            bindLibraryViewModelChanges()
        }
    }
    @Published private(set) var selectedPhotoID: String?
    @Published var notesText: String = ""
    @Published var tags: [String] = []
    @Published var labels: [PointLabel] = []
    @Published var areLabelsHidden = false
    @Published private(set) var notesSaveState: NotesSaveState = .clean
    @Published private(set) var notesStatusMessage: String?
    @Published private(set) var hasExternalDisplay = false
    @Published private(set) var isPresentationModeEnabled = false
    @Published private(set) var presentationDisplayID: CGDirectDisplayID?
    @Published var faceFeaturesEnabled = false
    @Published var isFaceOptInPromptPresented = false
    @Published var isFaceDisableDialogPresented = false
    @Published var isAudioRecordingEnabled = false
    @Published var isAudioRecordingBlinking = false
    @Published var isAudioStartDialogPresented = false
    @Published var shouldSaveRecordingFiles = true
    @Published var shouldAppendRecordingText = false
    @Published var shouldAppendRecordingSummary = false
    @Published var isAudioTranscriptionAvailable = false
    @Published var isAudioSummaryAvailable = false
    @Published var isAutoRecordingEnabled = true
    @Published var recordingRefreshToken = UUID()

    var selectedSidecarURL: URL? {
        selectedPhoto?.sidecarURL
    }

    var selectedSidecarExists: Bool {
        guard let url = selectedSidecarURL else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private let projectService: ProjectService
    private let sidecarService: SidecarService
    private let displayMonitor: DisplayMonitoring
    private let presentationWindowController: PresentationWindowControlling
    private let faceFeatureStore = FaceFeatureStore()
    private let userDefaults = UserDefaults.standard
    private let audioRecordingService = AudioRecordingService()
    private let audioTranscriptionService = AudioTranscriptionService()
    private let audioSummaryService = AudioSummaryService()
    private var faceFeatureKey: String?
    private var audioRecordingTask: Task<Void, Never>?
    private var audioBlinkTask: Task<Void, Never>?
    private var pendingAudioRecording: PendingAudioRecording?
    private var loadedSidecarDocument: SidecarDocument?
    private var autosaveTask: Task<Void, Never>?
    private var libraryViewModelChangeCancellable: AnyCancellable?
    private let autosaveDelayNanoseconds: UInt64 = 600_000_000
    private let summaryMinimumWordCount = 100
    private var shouldStartManualRecording = false

    private static let autoRecordPreferenceKey = "audio.autoRecordEnabled"
    private static let saveFilesPreferenceKey = "audio.saveRecordingFiles"
    private static let appendTextPreferenceKey = "audio.appendRecordingText"
    private static let appendSummaryPreferenceKey = "audio.appendRecordingSummary"

    init(
        projectService: ProjectService,
        sidecarService: SidecarService,
        displayMonitor: DisplayMonitoring,
        presentationWindowController: PresentationWindowControlling
    ) {
        self.projectService = projectService
        self.sidecarService = sidecarService
        self.displayMonitor = displayMonitor
        self.presentationWindowController = presentationWindowController
        loadAudioPreferences()
        bindLibraryViewModelChanges()
        displayMonitor.startMonitoring { [weak self] hasExternalDisplay in
            self?.handleDisplayAvailabilityChange(hasExternalDisplay)
        }
    }

    convenience init() {
        self.init(
            projectService: DefaultProjectService(),
            sidecarService: SidecarService(),
            displayMonitor: DisplayMonitor(),
            presentationWindowController: PresentationWindowController()
        )
    }

    func openProjectPicker() {
        flushPendingNotesIfNeeded()

        do {
            guard let selectedURL = try projectService.selectProjectFolder() else {
                return
            }
            openProject(at: selectedURL)
        } catch {
            statusMessage = "Failed to open folder: \(error.localizedDescription)"
        }
    }

    func reopenLastProject() {
        guard let lastProjectURL else {
            return
        }

        guard FileManager.default.fileExists(atPath: lastProjectURL.path) else {
            statusMessage = "Last project folder is no longer available."
            return
        }

        openProject(at: lastProjectURL)
    }

    var selectedPhoto: PhotoItem? {
        guard let selectedPhotoID else {
            return nil
        }

        return libraryViewModel.displayedItems.first(where: { $0.id == selectedPhotoID })
    }

    func revealSelectedSidecarInFinder() {
        guard let url = selectedSidecarURL, selectedSidecarExists else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    var canGoToPreviousPhoto: Bool {
        guard let currentPhotoIndex else {
            return false
        }
        return currentPhotoIndex > 0
    }

    var canGoToNextPhoto: Bool {
        guard let currentPhotoIndex else {
            return false
        }
        return currentPhotoIndex < (libraryViewModel.displayedItems.count - 1)
    }

    func openViewer(for item: PhotoItem) {
        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        selectedPhotoID = item.id
        loadNotesForSelectedPhoto()
        route = .viewer
        syncPresentationOutput()
        startAudioRecordingIfNeeded()
    }

    func openFaceGallery() {
        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        route = .faceGallery
        syncPresentationOutput()
    }

    func goToPreviousPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex > 0 else {
            return
        }

        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        selectedPhotoID = libraryViewModel.displayedItems[currentPhotoIndex - 1].id
        loadNotesForSelectedPhoto()
        syncPresentationOutput()
        startAudioRecordingIfNeeded()
    }

    func goToNextPhoto() {
        guard let currentPhotoIndex else {
            return
        }

        let nextIndex = currentPhotoIndex + 1
        guard nextIndex < libraryViewModel.displayedItems.count else {
            return
        }

        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        selectedPhotoID = libraryViewModel.displayedItems[nextIndex].id
        loadNotesForSelectedPhoto()
        syncPresentationOutput()
        startAudioRecordingIfNeeded()
    }

    func toggleAudioRecording() {
        if isAudioRecordingEnabled {
            isAudioRecordingEnabled = false
            stopAudioRecordingIfNeeded()
            isAudioTranscriptionAvailable = false
            isAudioSummaryAvailable = false
        } else {
            prepareAudioRecordingOptions()
            isAudioStartDialogPresented = true
        }
    }

    func confirmStartAudioRecording() {
        isAudioRecordingEnabled = true
        isAudioStartDialogPresented = false
        shouldStartManualRecording = true
        startAudioRecordingIfNeeded()
    }

    func cancelStartAudioRecording() {
        isAudioStartDialogPresented = false
    }

    private func prepareAudioRecordingOptions() {
        isAudioTranscriptionAvailable = audioTranscriptionService.isAvailable()
        isAudioSummaryAvailable = audioSummaryService.isAvailable()
        isAutoRecordingEnabled = preferredBool(Self.autoRecordPreferenceKey, default: true)
        shouldSaveRecordingFiles = preferredBool(Self.saveFilesPreferenceKey, default: true)
        let preferredAppendText = preferredBool(Self.appendTextPreferenceKey, default: false)
        let preferredAppendSummary = preferredBool(Self.appendSummaryPreferenceKey, default: false)
        shouldAppendRecordingText = isAudioTranscriptionAvailable && preferredAppendText
        shouldAppendRecordingSummary = isAudioSummaryAvailable && shouldAppendRecordingText && preferredAppendSummary
    }

    private func startAudioRecordingIfNeeded() {
        guard isAudioRecordingEnabled, let selectedPhoto else {
            return
        }
        if !isAutoRecordingEnabled && !shouldStartManualRecording {
            return
        }

        shouldStartManualRecording = false
        let url = audioRecordingURL(for: selectedPhoto)
        pendingAudioRecording = PendingAudioRecording(
            url: url,
            photo: selectedPhoto
        )
        audioRecordingTask?.cancel()
        audioRecordingTask = Task { [audioRecordingService] in
            do {
                try audioRecordingService.startRecording(to: url)
            } catch {
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Failed to start recording."
                    self?.isAudioRecordingEnabled = false
                }
            }
        }
    }

    private func stopAudioRecordingIfNeeded() {
        let shouldShowCompletionIndicator = pendingAudioRecording != nil
        audioRecordingTask?.cancel()
        audioRecordingTask = nil
        audioRecordingService.stopRecording()
        if let pending = pendingAudioRecording {
            pendingAudioRecording = nil
            Task { [weak self] in
                await self?.processRecording(pending)
            }
        }
        if shouldShowCompletionIndicator {
            blinkAudioRecordingIndicator()
        }
    }

    private func blinkAudioRecordingIndicator() {
        audioBlinkTask?.cancel()
        audioBlinkTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isAudioRecordingBlinking = true }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run { self.isAudioRecordingBlinking = false }
        }
    }

    private func audioRecordingURL(for photo: PhotoItem) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
        let baseName = photo.imageURL.deletingPathExtension().lastPathComponent
        let filename = "\(baseName)-\(timestamp).m4a"
        return photo.imageURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    private func processRecording(_ pending: PendingAudioRecording) async {
        if let duration = audioRecordingService.durationSeconds(at: pending.url),
           duration < 2 {
            trashAudioFile(at: pending.url)
            await MainActor.run { [weak self] in
                self?.recordingRefreshToken = UUID()
            }
            return
        }

        let finalURL = await audioRecordingService.trimSilence(at: pending.url)

        if shouldAppendRecordingText {
            await transcribeAndAppend(url: finalURL, for: pending.photo)
        }

        if !shouldSaveRecordingFiles {
            trashAudioFile(at: finalURL)
        }

        await MainActor.run { [weak self] in
            self?.recordingRefreshToken = UUID()
        }
    }

    private func transcribeAndAppend(url: URL, for photo: PhotoItem) async {
        let auth = await audioTranscriptionService.requestAuthorization()
        guard auth == .authorized else {
            await MainActor.run {
                statusMessage = "Speech recognition not authorized."
                shouldAppendRecordingText = false
                shouldAppendRecordingSummary = false
            }
            return
        }

        let text: String
        do {
            text = try await audioTranscriptionService.transcribeAudio(at: url)
        } catch {
            await MainActor.run {
                statusMessage = "Failed to transcribe audio."
            }
            return
        }

        await MainActor.run { [weak self] in
            self?.appendRecordingText(text, date: Date(), for: photo)
        }

        guard shouldAppendRecordingSummary else {
            return
        }

        let wordCount = countWords(in: text)
        if wordCount < summaryMinimumWordCount {
            await MainActor.run { [weak self] in
                self?.appendRecordingSummary(text, date: Date(), for: photo)
            }
            return
        }

        do {
            let summary = try await audioSummaryService.summarize(text)
            await MainActor.run { [weak self] in
                self?.appendRecordingSummary(summary, date: Date(), for: photo)
            }
        } catch {
            await MainActor.run {
                statusMessage = "Failed to summarize audio."
            }
        }

    }

    private func countWords(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func appendRecordingText(_ text: String, date: Date, for photo: PhotoItem) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
        let section = "\n\n## Audio - \(timestamp)\n\n\(text)\n"
        appendSection(section, for: photo)
    }

    private func appendRecordingSummary(_ text: String, date: Date, for photo: PhotoItem) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
        let section = "\n\n## Audio Summary - \(timestamp)\n\n\(text)\n"
        appendSection(section, for: photo)
    }

    private func appendSection(_ section: String, for photo: PhotoItem) {
        if selectedPhotoID == photo.id {
            notesText.append(contentsOf: section)
            notesSaveState = .dirty
            scheduleAutosave()
            return
        }

        do {
            var document = try sidecarService.readDocument(for: photo)
            document.notesMarkdown.append(contentsOf: section)
            try sidecarService.writeDocument(document, for: photo)
            libraryViewModel.updateSearch(
                for: photo,
                notes: document.notesMarkdown,
                tags: document.tags,
                labels: document.labels
            )
        } catch {
            statusMessage = "Failed to append audio notes."
        }
    }

    private func trashAudioFile(at url: URL) {
        _ = try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    func navigateToLibrary() {
        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        route = .library
        syncPresentationOutput()
    }

    func navigateToStart() {
        flushPendingNotesIfNeeded()
        stopAudioRecordingIfNeeded()
        route = .start
        syncPresentationOutput()
    }

    func setAppendRecordingText(_ isOn: Bool) {
        shouldAppendRecordingText = isOn
        userDefaults.set(isOn, forKey: Self.appendTextPreferenceKey)
        if !isOn {
            shouldAppendRecordingSummary = false
            userDefaults.set(false, forKey: Self.appendSummaryPreferenceKey)
        }
    }

    func setAppendRecordingSummary(_ isOn: Bool) {
        shouldAppendRecordingSummary = isOn
        userDefaults.set(isOn, forKey: Self.appendSummaryPreferenceKey)
    }

    func setSaveRecordingFiles(_ isOn: Bool) {
        shouldSaveRecordingFiles = isOn
        userDefaults.set(isOn, forKey: Self.saveFilesPreferenceKey)
    }

    func setAutoRecordingEnabled(_ isOn: Bool) {
        isAutoRecordingEnabled = isOn
        userDefaults.set(isOn, forKey: Self.autoRecordPreferenceKey)
    }

    private func loadAudioPreferences() {
        isAutoRecordingEnabled = preferredBool(Self.autoRecordPreferenceKey, default: true)
        shouldSaveRecordingFiles = preferredBool(Self.saveFilesPreferenceKey, default: true)
        shouldAppendRecordingText = preferredBool(Self.appendTextPreferenceKey, default: false)
        shouldAppendRecordingSummary = preferredBool(Self.appendSummaryPreferenceKey, default: false)
    }

    private func preferredBool(_ key: String, default defaultValue: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return userDefaults.bool(forKey: key)
    }

    func setPresentationModeEnabled(_ isEnabled: Bool) {
        if isEnabled {
            enablePresentationMode()
        } else {
            disablePresentationMode()
        }
    }

    func selectPresentationDisplay(_ displayID: CGDirectDisplayID) {
        presentationDisplayID = displayID
        if isPresentationModeEnabled {
            presentationWindowController.moveWindow(to: displayID)
            syncPresentationOutput()
        } else {
            enablePresentationMode()
        }
    }

    var availablePresentationDisplays: [PresentationDisplay] {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            return []
        }
        return screens.dropFirst().compactMap { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return PresentationDisplay(
                id: screenNumber.uint32Value,
                name: screen.localizedName
            )
        }
    }

    func updateNotesDraft(_ newValue: String) {
        notesText = newValue
        notesSaveState = .dirty
        notesStatusMessage = nil
        scheduleAutosave()
    }

    func addTag(_ rawTag: String) {
        let normalized = normalizeTag(rawTag)
        guard !normalized.isEmpty else {
            return
        }

        let exists = tags.contains { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        guard !exists else {
            return
        }

        tags.append(normalized)
        tags.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        notesSaveState = .dirty
        scheduleAutosave()
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        notesSaveState = .dirty
        scheduleAutosave()
    }

    func addLabel(x: Double, y: Double, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        let clampedX = min(max(x, 0), 1)
        let clampedY = min(max(y, 0), 1)
        let label = PointLabel(
            id: "lbl-\(UUID().uuidString.prefix(8))",
            x: clampedX,
            y: clampedY,
            text: trimmedText
        )
        labels.append(label)
        notesSaveState = .dirty
        scheduleAutosave()
    }

    func removeLabel(id: String) {
        labels.removeAll { $0.id == id }
        notesSaveState = .dirty
        scheduleAutosave()
    }

    func updateLabel(id: String, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        guard let index = labels.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existing = labels[index]
        labels[index] = PointLabel(
            id: existing.id,
            x: existing.x,
            y: existing.y,
            text: trimmedText
        )
        notesSaveState = .dirty
        scheduleAutosave()
    }

    private var currentPhotoIndex: Int? {
        guard let selectedPhotoID else {
            return nil
        }

        return libraryViewModel.displayedItems.firstIndex(where: { $0.id == selectedPhotoID })
    }

    private func loadNotesForSelectedPhoto() {
        guard let selectedPhoto else {
            loadedSidecarDocument = nil
            notesText = ""
            tags = []
            labels = []
            notesSaveState = .clean
            notesStatusMessage = nil
            return
        }

        do {
            let document = try sidecarService.readDocument(for: selectedPhoto)
            loadedSidecarDocument = document
            notesText = document.notesMarkdown
            tags = document.tags
            labels = document.labels
            notesSaveState = .clean
            notesStatusMessage = document.parseWarning
        } catch {
            loadedSidecarDocument = nil
            notesText = ""
            tags = []
            labels = []
            notesSaveState = .error(error.localizedDescription)
            notesStatusMessage = "Could not read sidecar file."
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let delay = autosaveDelayNanoseconds
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            await self?.saveNotesIfNeeded()
        }
    }

    private func flushPendingNotesIfNeeded() {
        autosaveTask?.cancel()
        autosaveTask = nil

        guard case .dirty = notesSaveState else {
            return
        }

        do {
            try saveNotesSync()
        } catch {
            notesSaveState = .error(error.localizedDescription)
            notesStatusMessage = "Autosave failed while changing photos."
        }
    }

    private func saveNotesIfNeeded() async {
        guard case .dirty = notesSaveState else {
            return
        }

        notesSaveState = .saving

        do {
            try saveNotesSync()
        } catch {
            notesSaveState = .error(error.localizedDescription)
            notesStatusMessage = "Autosave failed. Edits remain in memory."
        }
    }

    private func saveNotesSync() throws {
        guard let selectedPhoto else {
            return
        }

        var document = loadedSidecarDocument ?? SidecarDocument(
            frontMatterLines: ["photo: \(selectedPhoto.filename)"],
            notesMarkdown: "",
            tags: [],
            labels: [],
            hadFrontMatter: false,
            parseWarning: nil
        )
        document.notesMarkdown = notesText
        document.tags = tags
        document.labels = labels

        try sidecarService.writeDocument(document, for: selectedPhoto)
        loadedSidecarDocument = document
        libraryViewModel.updateSearch(
            for: selectedPhoto,
            notes: notesText,
            tags: tags,
            labels: labels
        )
        notesSaveState = .clean
        notesStatusMessage = nil
    }

    private func normalizeTag(_ input: String) -> String {
        input
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bindLibraryViewModelChanges() {
        libraryViewModelChangeCancellable = libraryViewModel.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func openProject(at url: URL) {
        stopAudioRecordingIfNeeded()
        projectRootURL = url
        lastProjectURL = url
        statusMessage = nil
        selectedPhotoID = nil
        libraryViewModel.loadProject(rootURL: url)
        faceFeatureKey = faceFeatureStore.persistentKey(for: url, userDefaults: userDefaults)
        updateFaceFeatureState()
        route = .library
        syncPresentationOutput()

        if faceFeaturesEnabled {
            startFaceIndexingIfNeeded()
        }
    }

    func enableFaceFeatures() {
        guard let rootURL = projectRootURL, let faceFeatureKey else {
            return
        }
        faceFeaturesEnabled = true
        userDefaults.set(true, forKey: faceFeatureStore.preferenceKey(forKey: faceFeatureKey))
        do {
            try faceFeatureStore.ensureCacheDirectory(forKey: faceFeatureKey)
        } catch {
            statusMessage = "Failed to create face feature cache."
        }
        startFaceIndexingIfNeeded()
    }

    func declineFaceFeatures() {
        guard let faceFeatureKey else {
            return
        }
        faceFeaturesEnabled = false
        userDefaults.set(false, forKey: faceFeatureStore.preferenceKey(forKey: faceFeatureKey))
        libraryViewModel.stopFaceIndexing()
    }

    func requestDisableFaceFeatures() {
        isFaceDisableDialogPresented = true
    }

    func disableFaceFeatures(purgeData: Bool) {
        guard let faceFeatureKey else {
            return
        }
        faceFeaturesEnabled = false
        userDefaults.set(false, forKey: faceFeatureStore.preferenceKey(forKey: faceFeatureKey))
        libraryViewModel.stopFaceIndexing()
        if purgeData {
            do {
                try faceFeatureStore.purgeCache(forKey: faceFeatureKey)
            } catch {
                statusMessage = "Failed to purge face feature cache."
            }
        }
        if route == .faceGallery {
            route = .library
        }
    }

    private func startFaceIndexingIfNeeded() {
        guard let rootURL = projectRootURL, let faceFeatureKey else {
            return
        }
        let storeURL = faceFeatureStore.indexFileURL(forKey: faceFeatureKey)
        libraryViewModel.startFaceIndexing(rootURL: rootURL, storeURL: storeURL, isEnabled: faceFeaturesEnabled)
    }

    private func updateFaceFeatureState() {
        guard let faceFeatureKey else {
            faceFeaturesEnabled = false
            isFaceOptInPromptPresented = true
            return
        }
        let key = faceFeatureStore.preferenceKey(forKey: faceFeatureKey)
        if let stored = userDefaults.object(forKey: key) as? Bool {
            faceFeaturesEnabled = stored
            if stored {
                try? faceFeatureStore.ensureCacheDirectory(forKey: faceFeatureKey)
            }
        } else {
            faceFeaturesEnabled = false
            isFaceOptInPromptPresented = true
        }
    }

    private func enablePresentationMode() {
        guard hasExternalDisplay else {
            statusMessage = "Presentation mode requires a second display."
            isPresentationModeEnabled = false
            return
        }

        if presentationDisplayID == nil {
            presentationDisplayID = availablePresentationDisplays.first?.id
        }

        isPresentationModeEnabled = true
        presentationWindowController.showWindow(on: presentationDisplayID)
        syncPresentationOutput()
    }

    private func disablePresentationMode() {
        isPresentationModeEnabled = false
        presentationWindowController.hideWindow()
    }

    private func handleDisplayAvailabilityChange(_ hasExternalDisplay: Bool) {
        self.hasExternalDisplay = hasExternalDisplay
        if let displayID = presentationDisplayID,
           !availablePresentationDisplays.contains(where: { $0.id == displayID }) {
            presentationDisplayID = availablePresentationDisplays.first?.id
        } else if presentationDisplayID == nil {
            presentationDisplayID = availablePresentationDisplays.first?.id
        }

        guard isPresentationModeEnabled else {
            return
        }

        if hasExternalDisplay {
            if let displayID = presentationDisplayID,
               availablePresentationDisplays.contains(where: { $0.id == displayID }) {
                presentationWindowController.showWindow(on: displayID)
            } else {
                presentationDisplayID = availablePresentationDisplays.first?.id
                presentationWindowController.showWindow(on: presentationDisplayID)
            }
            syncPresentationOutput()
        } else {
            disablePresentationMode()
            statusMessage = "Presentation mode ended because no second display is available."
        }
    }

    private func syncPresentationOutput() {
        guard isPresentationModeEnabled else {
            return
        }

        if route == .viewer, let selectedPhoto {
            presentationWindowController.updatePhoto(url: selectedPhoto.imageURL)
        } else {
            presentationWindowController.updatePhoto(url: nil)
        }
    }

    func suggestLabel(for featurePrint: Data) async -> String? {
        guard faceFeaturesEnabled, let faceFeatureKey else {
            return nil
        }
        let storeURL = faceFeatureStore.labelStoreURL(forKey: faceFeatureKey)
        let store = FaceLabelStore(storeURL: storeURL)
        return await store.suggestLabel(for: featurePrint)
    }

    func recordFaceLabelIfNeeded(labelText: String, featurePrint: Data?) {
        guard faceFeaturesEnabled, let faceFeatureKey, let featurePrint else {
            return
        }
        let storeURL = faceFeatureStore.labelStoreURL(forKey: faceFeatureKey)
        let store = FaceLabelStore(storeURL: storeURL)
        Task {
            await store.append(label: labelText, featurePrint: featurePrint)
        }
    }

    func faceIndexStoreURL() -> URL? {
        guard let faceFeatureKey else {
            return nil
        }
        return faceFeatureStore.indexFileURL(forKey: faceFeatureKey)
    }
}

private struct PendingAudioRecording {
    let url: URL
    let photo: PhotoItem
}

struct PresentationDisplay: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}
