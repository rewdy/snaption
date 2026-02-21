import Foundation
import CryptoKit

struct FaceFeatureStore {
    private let baseDirectory: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        self.baseDirectory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Snaption", isDirectory: true)
            .appendingPathComponent("FaceFeatures", isDirectory: true)
    }

    func preferenceKey(for rootURL: URL) -> String {
        "faceFeaturesEnabled.\(hashedKey(for: rootURL))"
    }

    func cacheDirectory(for rootURL: URL) -> URL {
        baseDirectory.appendingPathComponent(hashedKey(for: rootURL), isDirectory: true)
    }

    func indexFileURL(for rootURL: URL) -> URL {
        cacheDirectory(for: rootURL).appendingPathComponent("face-index.json")
    }

    func ensureCacheDirectory(for rootURL: URL) throws {
        let dir = cacheDirectory(for: rootURL)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func purgeCache(for rootURL: URL) throws {
        let dir = cacheDirectory(for: rootURL)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    private func hashedKey(for rootURL: URL) -> String {
        let data = Data(rootURL.path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
