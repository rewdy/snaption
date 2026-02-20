import Combine
import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var allItems: [PhotoItem] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var indexedCount = 0
    @Published private(set) var indexingErrorMessage: String?
    @Published private(set) var performance = LibraryPerformanceSnapshot.empty
    @Published var searchQuery: String = ""
    @Published var sortDirection: FilenameSortDirection = .ascending

    let thumbnailService = ThumbnailService()

    private let mediaIndexer: MediaIndexer
    private let sidecarService: SidecarService
    private var indexingTask: Task<Void, Never>?
    private var searchIndexTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var searchEntriesByPhotoID: [String: SearchEntry] = [:]
    private let clock = ContinuousClock()
    private var indexingStartTime: ContinuousClock.Instant?
    private var didRecordFirstPaint = false
    private var performanceMonitorTask: Task<Void, Never>?

    init(mediaIndexer: MediaIndexer, sidecarService: SidecarService) {
        self.mediaIndexer = mediaIndexer
        self.sidecarService = sidecarService
    }

    convenience init() {
        self.init(mediaIndexer: DefaultMediaIndexer(), sidecarService: SidecarService())
    }

    deinit {
        indexingTask?.cancel()
        searchIndexTask?.cancel()
        performanceMonitorTask?.cancel()
        prefetchTask?.cancel()
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
        didRecordFirstPaint = false
        indexingStartTime = clock.now
        thumbnailService.resetStats()
        performance = .empty
        updatePerformanceSnapshot()
        startPerformanceMonitoring()

        indexingTask?.cancel()
        searchIndexTask?.cancel()
        prefetchTask?.cancel()
        indexingTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                for try await batch in mediaIndexer.indexPhotos(in: rootURL) {
                    let sortedBatch = batch.sorted(by: Self.filenameOrder)
                    allItems = Self.mergeSorted(allItems, sortedBatch, by: Self.filenameOrder)
                    indexedCount = allItems.count
                    recordFirstPaintIfNeeded()
                    updatePerformanceSnapshot()
                    indexSearchContent(for: batch)
                    await Task.yield()
                }

                isIndexing = false
                performanceMonitorTask?.cancel()
                performanceMonitorTask = nil
                if let start = indexingStartTime {
                    let duration = start.duration(to: clock.now)
                    performance.fullIndexSeconds = Self.seconds(from: duration)
                }
                updatePerformanceSnapshot()
            } catch is CancellationError {
                isIndexing = false
                performanceMonitorTask?.cancel()
                performanceMonitorTask = nil
                updatePerformanceSnapshot()
            } catch {
                isIndexing = false
                indexingErrorMessage = "Indexing failed: \(error.localizedDescription)"
                performanceMonitorTask?.cancel()
                performanceMonitorTask = nil
                updatePerformanceSnapshot()
            }
        }
    }

    func toggleSortDirection() {
        sortDirection.toggle()
    }

    func updateSearch(for photo: PhotoItem, notes: String, tags: [String], labels: [PointLabel]) {
        searchEntriesByPhotoID[photo.id] = SearchEntry.from(notes: notes, tags: tags, labels: labels)
    }

    func prefetchThumbnails(for items: [PhotoItem], limit: Int = 72) {
        prefetchTask?.cancel()

        let candidates = Array(items.prefix(limit))
        guard !candidates.isEmpty else {
            return
        }

        let service = thumbnailService
        prefetchTask = Task.detached(priority: .utility) {
            for item in candidates {
                if Task.isCancelled {
                    return
                }
                _ = service.thumbnailData(for: item.imageURL, maxPixelSize: 360)
            }
        }
    }

    private func indexSearchContent(for batch: [PhotoItem]) {
        searchIndexTask = Task { [sidecarService] in
            var updates: [(String, SearchEntry)] = []
            updates.reserveCapacity(batch.count)

            for photo in batch {
                do {
                    let sidecar = try sidecarService.readDocument(for: photo)
                    let entry = SearchEntry.from(
                        notes: sidecar.notesMarkdown,
                        tags: sidecar.tags,
                        labels: sidecar.labels
                    )
                    updates.append((photo.id, entry))
                } catch {
                    continue
                }
            }

            for (photoID, entry) in updates {
                searchEntriesByPhotoID[photoID] = entry
            }
        }
    }

    private func recordFirstPaintIfNeeded() {
        guard !didRecordFirstPaint, indexedCount > 0, let start = indexingStartTime else {
            return
        }

        didRecordFirstPaint = true
        let duration = start.duration(to: clock.now)
        performance.firstPaintSeconds = Self.seconds(from: duration)
    }

    private func updatePerformanceSnapshot() {
        performance.indexedCount = indexedCount
        performance.thumbnailStats = thumbnailService.statsSnapshot()
        performance.memoryMB = ProcessMemory.residentMemoryMB()
    }

    private func startPerformanceMonitoring() {
        performanceMonitorTask?.cancel()
        performanceMonitorTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled, isIndexing {
                updatePerformanceSnapshot()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000.0
        return seconds + attoseconds
    }

    private static func filenameOrder(lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        if lhs.filename == rhs.filename {
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
        return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
    }

    private static func mergeSorted(
        _ lhs: [PhotoItem],
        _ rhs: [PhotoItem],
        by areInIncreasingOrder: (PhotoItem, PhotoItem) -> Bool
    ) -> [PhotoItem] {
        if lhs.isEmpty {
            return rhs
        }
        if rhs.isEmpty {
            return lhs
        }

        var merged: [PhotoItem] = []
        merged.reserveCapacity(lhs.count + rhs.count)

        var leftIndex = 0
        var rightIndex = 0
        while leftIndex < lhs.count, rightIndex < rhs.count {
            if areInIncreasingOrder(lhs[leftIndex], rhs[rightIndex]) {
                merged.append(lhs[leftIndex])
                leftIndex += 1
            } else {
                merged.append(rhs[rightIndex])
                rightIndex += 1
            }
        }

        if leftIndex < lhs.count {
            merged.append(contentsOf: lhs[leftIndex...])
        }
        if rightIndex < rhs.count {
            merged.append(contentsOf: rhs[rightIndex...])
        }

        return merged
    }
}
