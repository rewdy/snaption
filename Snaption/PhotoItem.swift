import Foundation

struct PhotoItem: Identifiable, Hashable, Sendable {
    let imageURL: URL
    let sidecarURL: URL
    let filename: String
    let relativePath: String

    nonisolated var id: String {
        imageURL.path
    }
}
