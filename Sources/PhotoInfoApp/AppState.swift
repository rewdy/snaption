import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .start
    @Published var projectRootURL: URL?
    @Published var statusMessage: String?
    @Published var libraryViewModel = LibraryViewModel()

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
            libraryViewModel.loadProject(rootURL: selectedURL)
            route = .library
        } catch {
            statusMessage = "Failed to open folder: \(error.localizedDescription)"
        }
    }

    func openViewerPlaceholder() {
        route = .viewer
    }

    func navigateToLibrary() {
        route = .library
    }

    func navigateToStart() {
        route = .start
    }
}
