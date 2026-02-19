import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var allItems: [PhotoItem] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var indexedCount = 0
    @Published private(set) var indexingErrorMessage: String?
    @Published var searchQuery: String = ""
    @Published var sortDirection: FilenameSortDirection = .ascending

    let thumbnailService = ThumbnailService()

    private let mediaIndexer: MediaIndexer
    private let sidecarService: SidecarService
    private var indexingTask: Task<Void, Never>?
    private var searchIndexTask: Task<Void, Never>?
    private var searchEntriesByPhotoID: [String: SearchEntry] = [:]

    init(
        mediaIndexer: MediaIndexer = DefaultMediaIndexer(),
        sidecarService: SidecarService = SidecarService()
    ) {
        self.mediaIndexer = mediaIndexer
        self.sidecarService = sidecarService
    }

    deinit {
        indexingTask?.cancel()
        searchIndexTask?.cancel()
    }

    var displayedItems: [PhotoItem] {
        let filtered: [PhotoItem]
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedQuery.isEmpty {
            filtered = allItems
        } else {
            filtered = allItems.filter { item in
                guard let entry = searchEntriesByPhotoID[item.id] else {
                    return false
                }
                return entry.matches(normalizedQuery)
            }
        }

        if sortDirection == .ascending {
            return filtered
        }
        return Array(filtered.reversed())
    }

    func loadProject(rootURL: URL) {
        self.rootURL = rootURL
        allItems = []
        searchEntriesByPhotoID = [:]
        searchQuery = ""
        indexedCount = 0
        indexingErrorMessage = nil
        isIndexing = true

        indexingTask?.cancel()
        searchIndexTask?.cancel()
        indexingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                for try await batch in mediaIndexer.indexPhotos(in: rootURL) {
                    allItems.append(contentsOf: batch)
                    allItems.sort(by: Self.filenameOrder)
                    indexedCount = allItems.count
                    indexSearchContent(for: batch)
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

    func updateSearch(for photo: PhotoItem, notes: String, tags: [String], labels: [PointLabel]) {
        searchEntriesByPhotoID[photo.id] = SearchEntry.from(notes: notes, tags: tags, labels: labels)
    }

    private func indexSearchContent(for batch: [PhotoItem]) {
        searchIndexTask = Task { [sidecarService] in
            let updates: [(String, SearchEntry)] = await Task.detached(priority: .utility) {
                var detachedUpdates: [(String, SearchEntry)] = []
                detachedUpdates.reserveCapacity(batch.count)

                for photo in batch {
                    do {
                        let sidecar = try sidecarService.readDocument(for: photo)
                        let entry = SearchEntry.from(
                            notes: sidecar.notesMarkdown,
                            tags: sidecar.tags,
                            labels: sidecar.labels
                        )
                        detachedUpdates.append((photo.id, entry))
                    } catch {
                        continue
                    }
                }

                return detachedUpdates
            }.value

            for (photoID, entry) in updates {
                searchEntriesByPhotoID[photoID] = entry
            }
        }
    }

    private static func filenameOrder(lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        if lhs.filename == rhs.filename {
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
        return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
    }
}
