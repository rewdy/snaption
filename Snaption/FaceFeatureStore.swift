import Foundation
import CryptoKit

struct FaceFeatureStore {
    static let bookmarkListKey = "faceFeatureBookmarks"
    private let baseDirectory: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        self.baseDirectory = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Snaption", isDirectory: true)
            .appendingPathComponent("FaceFeatures", isDirectory: true)
    }

    func preferenceKey(forKey key: String) -> String {
        "faceFeaturesEnabled.\(key)"
    }

    func cacheDirectory(forKey key: String) -> URL {
        baseDirectory.appendingPathComponent(key, isDirectory: true)
    }

    func indexFileURL(forKey key: String) -> URL {
        cacheDirectory(forKey: key).appendingPathComponent("face-index.json")
    }

    func labelStoreURL(forKey key: String) -> URL {
        cacheDirectory(forKey: key).appendingPathComponent("face-labels.json")
    }

    func ensureCacheDirectory(forKey key: String) throws {
        let dir = cacheDirectory(forKey: key)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func purgeCache(forKey key: String) throws {
        let dir = cacheDirectory(forKey: key)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    func persistentKey(for rootURL: URL, userDefaults: UserDefaults) -> String {
        let currentID = (try? rootURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier) as? NSObject
        var bookmarks = (userDefaults.array(forKey: Self.bookmarkListKey) as? [Data]) ?? []

        for (index, data) in bookmarks.enumerated() {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let candidateID = (try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier) as? NSObject
                if currentID?.isEqual(candidateID) == true {
                    if isStale, let refreshed = try? rootURL.bookmarkData(options: [.withSecurityScope]) {
                        bookmarks[index] = refreshed
                        userDefaults.set(bookmarks, forKey: Self.bookmarkListKey)
                        return hashedKey(for: refreshed)
                    }
                    return hashedKey(for: data)
                }
            }
        }

        if let bookmark = try? rootURL.bookmarkData(options: [.withSecurityScope]) {
            bookmarks.append(bookmark)
            userDefaults.set(bookmarks, forKey: Self.bookmarkListKey)
            return hashedKey(for: bookmark)
        }

        return hashedKey(forFallbackPath: rootURL.path)
    }

    private func hashedKey(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func hashedKey(forFallbackPath path: String) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
