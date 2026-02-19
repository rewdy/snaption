import Foundation

protocol MediaIndexer {
    func indexPhotos(in rootURL: URL) -> AsyncThrowingStream<[PhotoItem], Error>
}

struct DefaultMediaIndexer: MediaIndexer {
    private let supportedExtensions: Set<String> = ["jpg", "jpeg", "png"]
    private let batchSize = 75

    func indexPhotos(in rootURL: URL) -> AsyncThrowingStream<[PhotoItem], Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
                    guard let enumerator = FileManager.default.enumerator(
                        at: rootURL,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else {
                        continuation.finish()
                        return
                    }

                    var batch: [PhotoItem] = []
                    batch.reserveCapacity(batchSize)

                    while let object = enumerator.nextObject() {
                        guard let fileURL = object as? URL else {
                            continue
                        }

                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }

                        let values = try fileURL.resourceValues(forKeys: keys)
                        guard values.isRegularFile == true else {
                            continue
                        }

                        let fileExtension = fileURL.pathExtension.lowercased()
                        guard supportedExtensions.contains(fileExtension) else {
                            continue
                        }

                        let relativePath = relativePathFor(fileURL: fileURL, rootURL: rootURL)
                        let sidecarURL = fileURL.deletingPathExtension().appendingPathExtension("md")

                        batch.append(
                            PhotoItem(
                                imageURL: fileURL,
                                sidecarURL: sidecarURL,
                                filename: fileURL.lastPathComponent,
                                relativePath: relativePath
                            )
                        )

                        if batch.count >= batchSize {
                            continuation.yield(batch)
                            batch.removeAll(keepingCapacity: true)
                        }
                    }

                    if !batch.isEmpty {
                        continuation.yield(batch)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func relativePathFor(fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        if filePath.hasPrefix(rootPath + "/") {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return fileURL.lastPathComponent
    }
}
