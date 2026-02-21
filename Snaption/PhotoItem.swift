import Foundation

struct PhotoItem: Identifiable, Hashable, Sendable {
    let imageURL: URL
    let sidecarURL: URL
    let filename: String
    let relativePath: String
    let modifiedAt: Date?

    init(
        imageURL: URL,
        sidecarURL: URL,
        filename: String,
        relativePath: String,
        modifiedAt: Date? = nil
    ) {
        self.imageURL = imageURL
        self.sidecarURL = sidecarURL
        self.filename = filename
        self.relativePath = relativePath
        self.modifiedAt = modifiedAt
    }

    nonisolated var id: String {
        imageURL.path
    }
}
