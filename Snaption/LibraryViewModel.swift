import Combine
import Foundation

struct LibraryFolderGroup: Identifiable, Equatable {
    let path: String
    let items: [PhotoItem]

    var id: String { path }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var allItems: [PhotoItem] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var indexedCount = 0
    @Published private(set) var indexingErrorMessage: String?
    @Published private(set) var performance = LibraryPerformanceSnapshot.empty
    @Published var searchQuery: String = ""
    @Published var sortDirection: FilenameSortDirection = .filenameAscending
    @Published var groupByFolder = true

    let thumbnailService = ThumbnailService()

    private let mediaIndexer: MediaIndexer
    private let sidecarService: SidecarService
    private let uiPublishBatchSize: Int
    private var indexingTask: Task<Void, Never>?
    private var searchIndexTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var searchEntriesByPhotoID: [String: SearchEntry] = [:]
    private let clock = ContinuousClock()
    private var indexingStartTime: ContinuousClock.Instant?
    private var didRecordFirstPaint = false
    private var performanceMonitorTask: Task<Void, Never>?

    init(mediaIndexer: MediaIndexer, sidecarService: SidecarService, uiPublishBatchSize: Int = 25) {
        self.mediaIndexer = mediaIndexer
        self.sidecarService = sidecarService
        self.uiPublishBatchSize = max(1, uiPublishBatchSize)
    }

    convenience init() {
        self.init(
            mediaIndexer: DefaultMediaIndexer(),
            sidecarService: SidecarService(),
            uiPublishBatchSize: 25
        )
    }

    deinit {
        indexingTask?.cancel()
        searchIndexTask?.cancel()
        performanceMonitorTask?.cancel()
        prefetchTask?.cancel()
    }

    var displayedItems: [PhotoItem] {
        let filtered = filteredItems
        return sortedItems(filtered)
    }

    var displayedGroups: [LibraryFolderGroup] {
        var groupedItems: [String: [PhotoItem]] = [:]
        for item in displayedItems {
            let folderPath = Self.parentFolderPath(for: item)
            groupedItems[folderPath, default: []].append(item)
        }

        return groupedItems
            .map { LibraryFolderGroup(path: $0.key, items: $0.value) }
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
    }

    private var filteredItems: [PhotoItem] {
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
        return filtered
    }

    private func sortedItems(_ filtered: [PhotoItem]) -> [PhotoItem] {
        switch sortDirection {
        case .filenameAscending:
            return filtered.sorted(by: Self.filenameOrder)
        case .filenameDescending:
            return filtered.sorted { lhs, rhs in
                Self.filenameOrder(lhs: rhs, rhs: lhs)
            }
        case .modifiedAscending:
            return filtered.sorted(by: Self.modifiedOrderAscending)
        case .modifiedDescending:
            return filtered.sorted(by: Self.modifiedOrderDescending)
        }
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
                var indexedItems: [PhotoItem] = []
                var pendingSincePublish = 0
                for try await batch in mediaIndexer.indexPhotos(in: rootURL) {
                    let sortedBatch = batch.sorted(by: Self.filenameOrder)
                    indexedItems = Self.mergeSorted(indexedItems, sortedBatch, by: Self.filenameOrder)
                    indexedCount = indexedItems.count
                    pendingSincePublish += batch.count

                    let shouldFlushFirstPaint = allItems.isEmpty && !indexedItems.isEmpty
                    let shouldFlushBatch = pendingSincePublish >= uiPublishBatchSize
                    if shouldFlushFirstPaint || shouldFlushBatch {
                        allItems = indexedItems
                        pendingSincePublish = 0
                        recordFirstPaintIfNeeded()
                    }

                    updatePerformanceSnapshot()
                    indexSearchContent(for: batch)
                    await Task.yield()
                }

                if allItems.count != indexedItems.count {
                    allItems = indexedItems
                    recordFirstPaintIfNeeded()
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
        guard !didRecordFirstPaint, !allItems.isEmpty, let start = indexingStartTime else {
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

    private static func modifiedOrderAscending(lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return (lhs.modifiedAt ?? .distantPast) < (rhs.modifiedAt ?? .distantPast)
        }
        return filenameOrder(lhs: lhs, rhs: rhs)
    }

    private static func modifiedOrderDescending(lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
        return filenameOrder(lhs: lhs, rhs: rhs)
    }

    private static func parentFolderPath(for item: PhotoItem) -> String {
        var path = (item.relativePath as NSString).deletingLastPathComponent
        path = path.replacingOccurrences(of: "\\", with: "/")
        path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.isEmpty || path == "." {
            return "/"
        }
        return path
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
