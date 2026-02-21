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
        if let decoded = try? JSONDecoder().decode([String: FaceIndexEntry].self, from: data) {
            return decoded
        }
        if let legacy = try? JSONDecoder().decode([String: LegacyFaceIndexEntry].self, from: data) {
            return legacy.mapValues { legacyEntry in
                FaceIndexEntry(
                    photoPath: legacyEntry.photoPath,
                    photoModifiedAt: legacyEntry.photoModifiedAt,
                    faces: legacyEntry.faces.map { FaceIndexFace(bounds: $0, featurePrint: nil) }
                )
            }
        }
        return [:]
    }

    func save(_ entries: [String: FaceIndexEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        try? data.write(to: storeURL, options: [.atomic])
    }
}

private struct LegacyFaceIndexEntry: Codable {
    let photoPath: String
    let photoModifiedAt: Date
    let faces: [CGRect]
}
