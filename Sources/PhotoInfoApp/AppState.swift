import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .start
    @Published var projectRootURL: URL?
    @Published var statusMessage: String?
    @Published var libraryViewModel = LibraryViewModel()
    @Published private(set) var selectedPhotoID: String?
    @Published var notesText: String = ""
    @Published private(set) var notesSaveState: NotesSaveState = .clean
    @Published private(set) var notesStatusMessage: String?

    private let projectService: ProjectService
    private let sidecarService: SidecarService
    private var loadedSidecarDocument: SidecarDocument?
    private var autosaveTask: Task<Void, Never>?
    private let autosaveDelayNanoseconds: UInt64 = 600_000_000

    init(
        projectService: ProjectService = DefaultProjectService(),
        sidecarService: SidecarService = SidecarService()
    ) {
        self.projectService = projectService
        self.sidecarService = sidecarService
    }

    func openProjectPicker() {
        flushPendingNotesIfNeeded()

        do {
            guard let selectedURL = try projectService.selectProjectFolder() else {
                return
            }

            projectRootURL = selectedURL
            statusMessage = "Project opened: \(selectedURL.path)"
            selectedPhotoID = nil
            libraryViewModel.loadProject(rootURL: selectedURL)
            route = .library
        } catch {
            statusMessage = "Failed to open folder: \(error.localizedDescription)"
        }
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
    }

    func goToPreviousPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex > 0 else {
            return
        }

        flushPendingNotesIfNeeded()
        selectedPhotoID = libraryViewModel.displayedItems[currentPhotoIndex - 1].id
        loadNotesForSelectedPhoto()
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
    }

    func navigateToLibrary() {
        flushPendingNotesIfNeeded()
        route = .library
    }

    func navigateToStart() {
        flushPendingNotesIfNeeded()
        route = .start
    }

    func updateNotesDraft(_ newValue: String) {
        notesText = newValue
        notesSaveState = .dirty
        notesStatusMessage = nil
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
            notesSaveState = .clean
            notesStatusMessage = nil
            return
        }

        do {
            let document = try sidecarService.readDocument(for: selectedPhoto)
            loadedSidecarDocument = document
            notesText = document.notesMarkdown
            notesSaveState = .clean
            notesStatusMessage = document.parseWarning
        } catch {
            loadedSidecarDocument = nil
            notesText = ""
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
            hadFrontMatter: false,
            parseWarning: nil
        )
        document.notesMarkdown = notesText

        try sidecarService.writeDocument(document, for: selectedPhoto)
        loadedSidecarDocument = document
        notesSaveState = .clean
        notesStatusMessage = nil
    }
}
