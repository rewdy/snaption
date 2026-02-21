import Foundation

struct FaceIndexEntry: Codable, Sendable {
    let photoPath: String
    let photoModifiedAt: Date
    let faces: [FaceIndexFace]
}

struct FaceIndexFace: Codable, Sendable {
    let bounds: CGRect
    let featurePrint: Data?
}

actor FaceIndexStore {
    private let storeURL: URL

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func load() -> [String: FaceIndexEntry] {
        guard let data = try? Data(contentsOf: storeURL) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: FaceIndexEntry].self, from: data)) ?? [:]
    }

    func save(_ entries: [String: FaceIndexEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        try? data.write(to: storeURL, options: [.atomic])
    }
}
