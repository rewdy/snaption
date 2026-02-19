import Foundation

struct PhotoItem: Identifiable, Hashable {
    let imageURL: URL
    let sidecarURL: URL
    let filename: String
    let relativePath: String

    var id: String {
        imageURL.path
    }
}
