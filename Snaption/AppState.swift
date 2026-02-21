import Combine
import Foundation

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
    @Published private(set) var notesSaveState: NotesSaveState = .clean
    @Published private(set) var notesStatusMessage: String?
    @Published private(set) var hasExternalDisplay = false
    @Published private(set) var isPresentationModeEnabled = false

    private let projectService: ProjectService
    private let sidecarService: SidecarService
    private let displayMonitor: DisplayMonitoring
    private let presentationWindowController: PresentationWindowControlling
    private var loadedSidecarDocument: SidecarDocument?
    private var autosaveTask: Task<Void, Never>?
    private var libraryViewModelChangeCancellable: AnyCancellable?
    private let autosaveDelayNanoseconds: UInt64 = 600_000_000

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
        selectedPhotoID = item.id
        loadNotesForSelectedPhoto()
        route = .viewer
        syncPresentationOutput()
    }

    func goToPreviousPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex > 0 else {
            return
        }

        flushPendingNotesIfNeeded()
        selectedPhotoID = libraryViewModel.displayedItems[currentPhotoIndex - 1].id
        loadNotesForSelectedPhoto()
        syncPresentationOutput()
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
        selectedPhotoID = libraryViewModel.displayedItems[nextIndex].id
        loadNotesForSelectedPhoto()
        syncPresentationOutput()
    }

    func navigateToLibrary() {
        flushPendingNotesIfNeeded()
        route = .library
        syncPresentationOutput()
    }

    func navigateToStart() {
        flushPendingNotesIfNeeded()
        route = .start
        syncPresentationOutput()
    }

    func setPresentationModeEnabled(_ isEnabled: Bool) {
        if isEnabled {
            enablePresentationMode()
        } else {
            disablePresentationMode()
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
        projectRootURL = url
        lastProjectURL = url
        statusMessage = nil
        selectedPhotoID = nil
        libraryViewModel.loadProject(rootURL: url)
        route = .library
        syncPresentationOutput()
    }

    private func enablePresentationMode() {
        guard hasExternalDisplay else {
            statusMessage = "Presentation mode requires a second display."
            isPresentationModeEnabled = false
            return
        }

        isPresentationModeEnabled = true
        presentationWindowController.showWindow()
        syncPresentationOutput()
    }

    private func disablePresentationMode() {
        isPresentationModeEnabled = false
        presentationWindowController.hideWindow()
    }

    private func handleDisplayAvailabilityChange(_ hasExternalDisplay: Bool) {
        self.hasExternalDisplay = hasExternalDisplay

        guard isPresentationModeEnabled else {
            return
        }

        if hasExternalDisplay {
            presentationWindowController.showWindow()
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
}

