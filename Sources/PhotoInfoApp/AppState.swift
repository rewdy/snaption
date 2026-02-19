import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .start
    @Published var projectRootURL: URL?
    @Published var statusMessage: String?

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
