import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var allItems: [PhotoItem] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var indexedCount = 0
    @Published private(set) var indexingErrorMessage: String?
    @Published var sortDirection: FilenameSortDirection = .ascending

    let thumbnailService = ThumbnailService()

    private let mediaIndexer: MediaIndexer
    private var indexingTask: Task<Void, Never>?

    init(mediaIndexer: MediaIndexer = DefaultMediaIndexer()) {
        self.mediaIndexer = mediaIndexer
    }

    deinit {
        indexingTask?.cancel()
    }

    var displayedItems: [PhotoItem] {
        if sortDirection == .ascending {
            return allItems
        }
        return Array(allItems.reversed())
    }

    func loadProject(rootURL: URL) {
        self.rootURL = rootURL
        allItems = []
        indexedCount = 0
        indexingErrorMessage = nil
        isIndexing = true

        indexingTask?.cancel()
        indexingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                for try await batch in mediaIndexer.indexPhotos(in: rootURL) {
                    allItems.append(contentsOf: batch)
                    allItems.sort(by: Self.filenameOrder)
                    indexedCount = allItems.count
                }

                isIndexing = false
            } catch is CancellationError {
                isIndexing = false
            } catch {
                isIndexing = false
                indexingErrorMessage = "Indexing failed: \(error.localizedDescription)"
            }
        }
    }

    func toggleSortDirection() {
        sortDirection.toggle()
    }

    private static func filenameOrder(lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        if lhs.filename == rhs.filename {
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
        return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
    }
}
