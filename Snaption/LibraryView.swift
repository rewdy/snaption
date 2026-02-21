import AppKit
import SwiftUI

struct LibraryView: View {
    @ObservedObject var appState: AppState
    @State private var collapsedFolderPaths: Set<String> = []

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12),
    ]

    private var folderHeaderBackground: Color {
        Color(nsColor: NSColor(name: nil) { _ in
            let base = NSColor.windowBackgroundColor
            return base.blended(withFraction: 0.12, of: .labelColor) ?? base
        })
    }

    private struct PrefetchKey: Equatable {
        let count: Int
        let query: String
        let sortDirection: FilenameSortDirection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Library")
                    .font(.title2)
                    .bold()
                Spacer()

                if let rootURL = appState.libraryViewModel.rootURL {
                    Text("Project folder: \(rootURL.path)")
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

            HStack(spacing: 12) {
                Picker("", selection: $appState.libraryViewModel.groupByFolder) {
                    Text("Grouped").tag(true)
                    Text("Flat").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Picker("Sort", selection: $appState.libraryViewModel.sortDirection) {
                    Text("Filename \u{2191}").tag(FilenameSortDirection.filenameAscending)
                    Text("Filename \u{2193}").tag(FilenameSortDirection.filenameDescending)
                    Text("Date Modified \u{2191}").tag(FilenameSortDirection.modifiedAscending)
                    Text("Date Modified \u{2193}").tag(FilenameSortDirection.modifiedDescending)
                }
                .pickerStyle(.menu)
                .disabled(appState.libraryViewModel.allItems.isEmpty)

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

            #if DEBUG
            performancePanel
            #endif

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
                        LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                            ForEach(appState.libraryViewModel.displayedGroups) { group in
                                Section {
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
                                } header: {
                                    Button {
                                        toggleFolderCollapse(path: group.path)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isFolderCollapsed(path: group.path) ? "chevron.right" : "chevron.down")
                                                .font(.subheadline)
                                            Text(group.path)
                                                .font(.body.weight(.semibold))
                                            Spacer()
                                            Text("\(group.items.count)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                        .background(folderHeaderBackground.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .zIndex(10)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            sortDirection: appState.libraryViewModel.sortDirection
        )) {
            appState.libraryViewModel.prefetchThumbnails(for: appState.libraryViewModel.displayedItems)
        }
        .onChange(of: appState.libraryViewModel.displayedGroups.map(\.path), initial: false) { _, newPaths in
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
    private let thumbnailHeight: CGFloat = 132

    var body: some View {
        Button {
            onOpen(item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.12))

                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: thumbnailHeight)

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
