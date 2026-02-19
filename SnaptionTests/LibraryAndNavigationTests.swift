import Foundation
import XCTest
@testable import Snaption

@MainActor
final class LibraryAndNavigationTests: XCTestCase {
    func testLibrarySortAscendingAndDescendingByFilename() async throws {
        let items = [
            makePhotoItem(name: "IMG_0100.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
            makePhotoItem(name: "IMG_0010.jpg"),
        ]
        let viewModel = LibraryViewModel(mediaIndexer: MockMediaIndexer(batches: [items]))

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0002.jpg", "IMG_0010.jpg", "IMG_0100.jpg"])

        viewModel.toggleSortDirection()
        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0100.jpg", "IMG_0010.jpg", "IMG_0002.jpg"])
    }

    func testLibrarySearchMatchesNotesTagsAndLabels() async throws {
        let one = makePhotoItem(name: "IMG_0001.jpg")
        let two = makePhotoItem(name: "IMG_0002.jpg")
        let three = makePhotoItem(name: "IMG_0003.jpg")
        let viewModel = LibraryViewModel(mediaIndexer: MockMediaIndexer(batches: [[one, two, three]]))

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        viewModel.updateSearch(for: one, notes: "beach vacation", tags: ["summer"], labels: [])
        viewModel.updateSearch(for: two, notes: "birthday dinner", tags: [], labels: [PointLabel(id: "lbl-1", x: 0.1, y: 0.2, text: "Mom")])
        viewModel.updateSearch(for: three, notes: "old album", tags: ["archive"], labels: [])

        viewModel.searchQuery = "vacation"
        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0001.jpg"])

        viewModel.searchQuery = "mom"
        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0002.jpg"])

        viewModel.searchQuery = "archive"
        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0003.jpg"])
    }

    func testAppStateNavigationRespectsSortDirectionAndBounds() async throws {
        let items = [
            makePhotoItem(name: "IMG_0003.jpg"),
            makePhotoItem(name: "IMG_0001.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
        ]
        let viewModel = LibraryViewModel(mediaIndexer: MockMediaIndexer(batches: [items]))
        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        let appState = AppState(sidecarService: SidecarService())
        appState.libraryViewModel = viewModel

        appState.openViewer(for: viewModel.displayedItems[0])
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0001.jpg")
        XCTAssertFalse(appState.canGoToPreviousPhoto)
        XCTAssertTrue(appState.canGoToNextPhoto)

        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0002.jpg")

        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0003.jpg")
        XCTAssertFalse(appState.canGoToNextPhoto)

        viewModel.toggleSortDirection()
        appState.openViewer(for: viewModel.displayedItems[0])
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0003.jpg")
        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0002.jpg")
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
