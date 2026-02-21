import AppKit
import SwiftUI

struct LibraryView: View {
    @ObservedObject var appState: AppState
    @State private var collapsedFolderPaths: Set<String> = []

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12),
    ]

    private struct PrefetchKey: Equatable {
        let count: Int
        let query: String
        let isAscending: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Library")
                    .font(.title2)
                    .bold()
                Spacer()

                if let rootURL = appState.libraryViewModel.rootURL {
                    Text("Project root: \(rootURL.path)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 560, alignment: .trailing)
                } else {
                    Text("No project selected.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button("Change") {
                    appState.openProjectPicker()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Sort: \(appState.libraryViewModel.sortDirection.label)") {
                    appState.libraryViewModel.toggleSortDirection()
                }
                .buttonStyle(.bordered)
                .disabled(appState.libraryViewModel.allItems.isEmpty)

                Toggle("Group by folder", isOn: $appState.libraryViewModel.groupByFolder)
                    .toggleStyle(.switch)

                if appState.libraryViewModel.isIndexing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing \(appState.libraryViewModel.indexedCount) photos...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(appState.libraryViewModel.allItems.count) photos indexed")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            performancePanel

            HStack(spacing: 8) {
                TextField("Search notes, tags, labels", text: $appState.libraryViewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                if !appState.libraryViewModel.searchQuery.isEmpty {
                    Button("Clear") {
                        appState.libraryViewModel.searchQuery = ""
                    }
                    .buttonStyle(.bordered)
                }
                Text("\(appState.libraryViewModel.displayedItems.count) shown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let indexingErrorMessage = appState.libraryViewModel.indexingErrorMessage {
                Text(indexingErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if appState.libraryViewModel.displayedItems.isEmpty && !appState.libraryViewModel.isIndexing {
                ContentUnavailableView(
                    "No photos found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Supported formats: jpg, jpeg, png")
                )
            } else {
                ScrollView {
                    if appState.libraryViewModel.groupByFolder {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(appState.libraryViewModel.displayedGroups) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Button {
                                        toggleFolderCollapse(path: group.path)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isFolderCollapsed(path: group.path) ? "chevron.right" : "chevron.down")
                                                .font(.caption)
                                            Text(group.path)
                                                .font(.headline)
                                            Spacer()
                                            Text("\(group.items.count)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if !isFolderCollapsed(path: group.path) {
                                        LazyVGrid(columns: columns, spacing: 12) {
                                            ForEach(group.items) { item in
                                                ThumbnailCell(
                                                    item: item,
                                                    thumbnailService: appState.libraryViewModel.thumbnailService
                                                ) { selectedItem in
                                                    appState.openViewer(for: selectedItem)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(appState.libraryViewModel.displayedItems) { item in
                                ThumbnailCell(
                                    item: item,
                                    thumbnailService: appState.libraryViewModel.thumbnailService
                                ) { selectedItem in
                                    appState.openViewer(for: selectedItem)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: PrefetchKey(
            count: appState.libraryViewModel.displayedItems.count,
            query: appState.libraryViewModel.searchQuery,
            isAscending: appState.libraryViewModel.sortDirection == .ascending
        )) {
            appState.libraryViewModel.prefetchThumbnails(for: appState.libraryViewModel.displayedItems)
        }
        .onChange(of: appState.libraryViewModel.displayedGroups.map(\.path)) { newPaths in
            let valid = Set(newPaths)
            collapsedFolderPaths = collapsedFolderPaths.intersection(valid)
        }
    }

    private func isFolderCollapsed(path: String) -> Bool {
        collapsedFolderPaths.contains(path)
    }

    private func toggleFolderCollapse(path: String) {
        if collapsedFolderPaths.contains(path) {
            collapsedFolderPaths.remove(path)
        } else {
            collapsedFolderPaths.insert(path)
        }
    }
}

extension LibraryView {
    private var performancePanel: some View {
        let metrics = appState.libraryViewModel.performance
        return VStack(alignment: .leading, spacing: 4) {
            Text("Performance")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                metric(label: "First paint", value: formatSeconds(metrics.firstPaintSeconds))
                metric(label: "Full index", value: formatSeconds(metrics.fullIndexSeconds))
                metric(label: "Memory", value: formatMB(metrics.memoryMB))
                metric(label: "Thumb hit rate", value: formatHitRate(metrics.thumbnailStats))
                metric(label: "Thumb entries", value: "\(metrics.thumbnailStats.trackedEntries)")
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .monospacedDigit()
        }
    }

    private func formatSeconds(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return String(format: "%.2fs", value)
    }

    private func formatMB(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return String(format: "%.1f MB", value)
    }

    private func formatHitRate(_ stats: ThumbnailCacheStats) -> String {
        guard stats.requests > 0 else {
            return "--"
        }

        let rate = Double(stats.hits) / Double(stats.requests)
        return String(format: "%.0f%%", rate * 100)
    }
}

private struct ThumbnailCell: View {
    let item: PhotoItem
    let thumbnailService: ThumbnailService
    let onOpen: (PhotoItem) -> Void

    @State private var image: NSImage?

    var body: some View {
        Button {
            onOpen(item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(item.filename)
                    .font(.caption)
                    .lineLimit(1)

                Text(item.relativePath)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .task(id: item.id) {
            image = nil
            let data = await Task.detached(priority: .utility) {
                thumbnailService.thumbnailData(for: item.imageURL, maxPixelSize: 360)
            }.value
            guard !Task.isCancelled else {
                return
            }
            if let data {
                image = NSImage(data: data)
            }
        }
    }
}
