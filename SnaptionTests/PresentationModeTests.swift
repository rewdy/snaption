import Foundation
import XCTest
@testable import Snaption

@MainActor
final class PresentationModeTests: XCTestCase {
    func testEnablePresentationModeRequiresExternalDisplay() async {
        let displayMonitor = MockDisplayMonitor(initialHasExternalDisplay: false)
        let presentationController = MockPresentationWindowController()
        let appState = AppState(
            projectService: DefaultProjectService(),
            sidecarService: SidecarService(),
            displayMonitor: displayMonitor,
            presentationWindowController: presentationController
        )

        appState.setPresentationModeEnabled(true)

        XCTAssertFalse(appState.isPresentationModeEnabled)
        XCTAssertEqual(appState.statusMessage, "Presentation mode requires a second display.")
        XCTAssertEqual(presentationController.showWindowCallCount, 0)
    }

    func testPresentationModeShowsPhotoInViewerAndBlackOutsideViewer() async {
        let displayMonitor = MockDisplayMonitor(initialHasExternalDisplay: true)
        let presentationController = MockPresentationWindowController()
        let appState = AppState(
            projectService: DefaultProjectService(),
            sidecarService: SidecarService(),
            displayMonitor: displayMonitor,
            presentationWindowController: presentationController
        )

        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(
                batches: [[makePhotoItem(name: "IMG_0001.jpg"), makePhotoItem(name: "IMG_0002.jpg")]]
            ),
            sidecarService: SidecarService()
        )
        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 2)
        appState.libraryViewModel = viewModel

        appState.setPresentationModeEnabled(true)
        XCTAssertTrue(appState.isPresentationModeEnabled)
        XCTAssertEqual(presentationController.showWindowCallCount, 1)
        XCTAssertEqual(presentationController.updatedPhotoURLs.count, 1)
        XCTAssertNil(presentationController.updatedPhotoURLs.last!)

        appState.openViewer(for: viewModel.displayedItems[0])
        XCTAssertEqual(presentationController.updatedPhotoURLs.last, viewModel.displayedItems[0].imageURL)

        appState.navigateToLibrary()
        XCTAssertNil(presentationController.updatedPhotoURLs.last!)

        appState.setPresentationModeEnabled(false)
        XCTAssertFalse(appState.isPresentationModeEnabled)
        XCTAssertEqual(presentationController.hideWindowCallCount, 1)
    }

    func testPresentationModeAutoDisablesWhenExternalDisplayDisconnects() async {
        let displayMonitor = MockDisplayMonitor(initialHasExternalDisplay: true)
        let presentationController = MockPresentationWindowController()
        let appState = AppState(
            projectService: DefaultProjectService(),
            sidecarService: SidecarService(),
            displayMonitor: displayMonitor,
            presentationWindowController: presentationController
        )

        appState.setPresentationModeEnabled(true)
        XCTAssertTrue(appState.isPresentationModeEnabled)

        displayMonitor.simulateChange(hasExternalDisplay: false)

        XCTAssertFalse(appState.isPresentationModeEnabled)
        XCTAssertEqual(
            appState.statusMessage,
            "Presentation mode ended because no second display is available."
        )
        XCTAssertEqual(presentationController.hideWindowCallCount, 1)
    }

    private func waitUntilIndexed(_ viewModel: LibraryViewModel, expectedCount: Int) async {
        for _ in 0..<100 {
            if viewModel.indexedCount >= expectedCount, !viewModel.isIndexing {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for indexing to complete")
    }

    private func makePhotoItem(name: String) -> PhotoItem {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let imageURL = directory.appendingPathComponent(name)
        let sidecarURL = directory.appendingPathComponent((name as NSString).deletingPathExtension + ".md")
        return PhotoItem(
            imageURL: imageURL,
            sidecarURL: sidecarURL,
            filename: name,
            relativePath: name
        )
    }
}

private final class MockDisplayMonitor: DisplayMonitoring {
    var hasExternalDisplay: Bool
    private var onChange: ((Bool) -> Void)?

    init(initialHasExternalDisplay: Bool) {
        hasExternalDisplay = initialHasExternalDisplay
    }

    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        onChange(hasExternalDisplay)
    }

    func stopMonitoring() {
        onChange = nil
    }

    func simulateChange(hasExternalDisplay: Bool) {
        self.hasExternalDisplay = hasExternalDisplay
        onChange?(hasExternalDisplay)
    }
}

private final class MockPresentationWindowController: PresentationWindowControlling {
    private(set) var showWindowCallCount = 0
    private(set) var hideWindowCallCount = 0
    private(set) var updatedPhotoURLs: [URL?] = []

    func showWindow() {
        showWindowCallCount += 1
    }

    func updatePhoto(url: URL?) {
        updatedPhotoURLs.append(url)
    }

    func hideWindow() {
        hideWindowCallCount += 1
    }
}

private struct MockMediaIndexer: MediaIndexer {
    let batches: [[PhotoItem]]

    func indexPhotos(in rootURL: URL) -> AsyncThrowingStream<[PhotoItem], Error> {
        AsyncThrowingStream { continuation in
            for batch in batches {
                continuation.yield(batch)
            }
            continuation.finish()
        }
    }
}
