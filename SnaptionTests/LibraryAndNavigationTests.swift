import Foundation
import XCTest
@testable import Snaption

@MainActor
final class LibraryAndNavigationTests: XCTestCase {
    func testLibraryFirstPaintArrivesBeforeIndexingCompletes() async throws {
        let firstBatch = [
            makePhotoItem(name: "IMG_0001.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
        ]
        let secondBatch = [
            makePhotoItem(name: "IMG_0003.jpg"),
            makePhotoItem(name: "IMG_0004.jpg"),
        ]
        let viewModel = LibraryViewModel(
            mediaIndexer: DelayedMockMediaIndexer(firstBatch: firstBatch, secondBatch: secondBatch),
            sidecarService: SidecarService()
        )

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntil {
            viewModel.indexedCount >= 2
        }

        XCTAssertEqual(viewModel.displayedItems.count, 2)
        XCTAssertTrue(viewModel.isIndexing)
        XCTAssertNotNil(viewModel.performance.firstPaintSeconds)
        XCTAssertNil(viewModel.performance.fullIndexSeconds)

        await waitUntilIndexed(viewModel, expectedCount: 4)
        XCTAssertEqual(viewModel.displayedItems.count, 4)
        XCTAssertFalse(viewModel.isIndexing)
        XCTAssertNotNil(viewModel.performance.fullIndexSeconds)
    }

    func testLibrarySortAscendingAndDescendingByFilename() async throws {
        let items = [
            makePhotoItem(name: "IMG_0100.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
            makePhotoItem(name: "IMG_0010.jpg"),
        ]
        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(batches: [items]),
            sidecarService: SidecarService()
        )

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        XCTAssertEqual(viewModel.displayedItems.map { $0.filename }, ["IMG_0002.jpg", "IMG_0010.jpg", "IMG_0100.jpg"])

        viewModel.toggleSortDirection()
        XCTAssertEqual(viewModel.displayedItems.map { $0.filename }, ["IMG_0100.jpg", "IMG_0010.jpg", "IMG_0002.jpg"])
    }

    func testLibrarySearchMatchesNotesTagsAndLabels() async throws {
        let one = makePhotoItem(name: "IMG_0001.jpg")
        let two = makePhotoItem(name: "IMG_0002.jpg")
        let three = makePhotoItem(name: "IMG_0003.jpg")
        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(batches: [[one, two, three]]),
            sidecarService: SidecarService()
        )

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        viewModel.updateSearch(for: one, notes: "beach vacation", tags: ["summer"], labels: [])
        viewModel.updateSearch(for: two, notes: "birthday dinner", tags: [], labels: [PointLabel(id: "lbl-1", x: 0.1, y: 0.2, text: "Mom")])
        viewModel.updateSearch(for: three, notes: "old album", tags: ["archive"], labels: [])

        viewModel.searchQuery = "vacation"
        XCTAssertEqual(viewModel.displayedItems.map { $0.filename }, ["IMG_0001.jpg"])

        viewModel.searchQuery = "mom"
        XCTAssertEqual(viewModel.displayedItems.map { $0.filename }, ["IMG_0002.jpg"])

        viewModel.searchQuery = "archive"
        XCTAssertEqual(viewModel.displayedItems.map { $0.filename }, ["IMG_0003.jpg"])
    }

    func testAppStateNavigationRespectsSortDirectionAndBounds() async throws {
        let items = [
            makePhotoItem(name: "IMG_0003.jpg"),
            makePhotoItem(name: "IMG_0001.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
        ]
        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(batches: [items]),
            sidecarService: SidecarService()
        )
        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        let appState = AppState()
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

    func testKeyboardEquivalentNavigationDoesNotWrapAtBounds() async throws {
        let items = [
            makePhotoItem(name: "IMG_0001.jpg"),
            makePhotoItem(name: "IMG_0002.jpg"),
            makePhotoItem(name: "IMG_0003.jpg"),
        ]
        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(batches: [items]),
            sidecarService: SidecarService()
        )
        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 3)

        let appState = AppState()
        appState.libraryViewModel = viewModel
        appState.openViewer(for: viewModel.displayedItems[0])
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0001.jpg")

        // Equivalent to pressing left on the first item.
        appState.goToPreviousPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0001.jpg")

        // Equivalent to pressing right repeatedly.
        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0002.jpg")
        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0003.jpg")

        // Equivalent to pressing right on the final item.
        appState.goToNextPhoto()
        XCTAssertEqual(appState.selectedPhoto?.filename, "IMG_0003.jpg")
    }

    func testLibraryBatchPublishingFlushesInConfiguredChunks() async throws {
        let items = (1...5).map { makePhotoItem(name: String(format: "IMG_%04d.jpg", $0)) }
        let viewModel = LibraryViewModel(
            mediaIndexer: IncrementalMockMediaIndexer(items: items, delayNanoseconds: 35_000_000),
            sidecarService: SidecarService(),
            uiPublishBatchSize: 3
        )

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))

        await waitUntil {
            viewModel.indexedCount >= 2
        }

        // First paint should flush immediately.
        XCTAssertEqual(viewModel.displayedItems.count, 1)

        await waitUntil {
            viewModel.indexedCount >= 4
        }

        // After 3 additional indexed items, UI should flush again.
        XCTAssertEqual(viewModel.displayedItems.count, 4)

        await waitUntilIndexed(viewModel, expectedCount: 5)
        XCTAssertEqual(viewModel.displayedItems.count, 5)
    }

    func testLibraryFolderGroupsSortByPathAndRespectGroupToggle() async throws {
        let items = [
            makePhotoItem(name: "IMG_0003.jpg", relativePath: "styles/posted/IMG_0003.jpg"),
            makePhotoItem(name: "IMG_0001.jpg", relativePath: "styles/IMG_0001.jpg"),
            makePhotoItem(name: "IMG_0002.jpg", relativePath: "IMG_0002.jpg"),
            makePhotoItem(name: "IMG_0004.jpg", relativePath: "styles/posted/IMG_0004.jpg"),
        ]
        let viewModel = LibraryViewModel(
            mediaIndexer: MockMediaIndexer(batches: [items]),
            sidecarService: SidecarService()
        )

        viewModel.loadProject(rootURL: URL(fileURLWithPath: "/tmp/photos"))
        await waitUntilIndexed(viewModel, expectedCount: 4)

        XCTAssertTrue(viewModel.groupByFolder)
        XCTAssertEqual(viewModel.displayedGroups.map(\.path), ["/", "styles", "styles/posted"])
        XCTAssertEqual(viewModel.displayedGroups.first(where: { $0.path == "styles/posted" })?.items.map(\.filename), ["IMG_0003.jpg", "IMG_0004.jpg"])

        viewModel.groupByFolder = false
        XCTAssertEqual(viewModel.displayedItems.map(\.filename), ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg", "IMG_0004.jpg"])
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

    private func waitUntil(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if predicate() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makePhotoItem(name: String, relativePath: String? = nil) -> PhotoItem {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let imageURL = directory.appendingPathComponent(name)
        let sidecarURL = directory.appendingPathComponent((name as NSString).deletingPathExtension + ".md")
        let itemRelativePath = relativePath ?? name
        return PhotoItem(
            imageURL: imageURL,
            sidecarURL: sidecarURL,
            filename: name,
            relativePath: itemRelativePath
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

private struct DelayedMockMediaIndexer: MediaIndexer {
    let firstBatch: [PhotoItem]
    let secondBatch: [PhotoItem]

    func indexPhotos(in rootURL: URL) -> AsyncThrowingStream<[PhotoItem], Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .utility) {
                continuation.yield(firstBatch)
                try? await Task.sleep(nanoseconds: 120_000_000)
                continuation.yield(secondBatch)
                continuation.finish()
            }
        }
    }
}

private struct IncrementalMockMediaIndexer: MediaIndexer {
    let items: [PhotoItem]
    let delayNanoseconds: UInt64

    func indexPhotos(in rootURL: URL) -> AsyncThrowingStream<[PhotoItem], Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .utility) {
                for item in items {
                    continuation.yield([item])
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                }
                continuation.finish()
            }
        }
    }
}
