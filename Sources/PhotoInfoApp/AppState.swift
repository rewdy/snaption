import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .start
    @Published var projectRootURL: URL?
    @Published var statusMessage: String?
    @Published var libraryViewModel = LibraryViewModel()
    @Published private(set) var selectedPhotoID: String?

    private let projectService: ProjectService

    init(projectService: ProjectService = DefaultProjectService()) {
        self.projectService = projectService
    }

    func openProjectPicker() {
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
        selectedPhotoID = item.id
        route = .viewer
    }

    func goToPreviousPhoto() {
        guard let currentPhotoIndex, currentPhotoIndex > 0 else {
            return
        }

        selectedPhotoID = libraryViewModel.displayedItems[currentPhotoIndex - 1].id
    }

    func goToNextPhoto() {
        guard let currentPhotoIndex else {
            return
        }

        let nextIndex = currentPhotoIndex + 1
        guard nextIndex < libraryViewModel.displayedItems.count else {
            return
        }

        selectedPhotoID = libraryViewModel.displayedItems[nextIndex].id
    }

    func navigateToLibrary() {
        route = .library
    }

    func navigateToStart() {
        route = .start
    }

    private var currentPhotoIndex: Int? {
        guard let selectedPhotoID else {
            return nil
        }

        return libraryViewModel.displayedItems.firstIndex(where: { $0.id == selectedPhotoID })
    }
}
