import AppKit
import Foundation
import ImageIO

final class ThumbnailService: @unchecked Sendable {
    nonisolated(unsafe) private let cache = NSCache<NSString, NSData>()
    private let lock = NSLock()
    nonisolated(unsafe) private var requests = 0
    nonisolated(unsafe) private var hits = 0
    nonisolated(unsafe) private var misses = 0
    nonisolated(unsafe) private var trackedKeys = Set<String>()

    init() {
        cache.countLimit = 900
        cache.totalCostLimit = 256 * 1_048_576
    }

    nonisolated func thumbnailData(for imageURL: URL, maxPixelSize: Int) -> Data? {
        let cacheKeyString = "\(imageURL.path)#\(maxPixelSize)"
        let cacheKey = cacheKeyString as NSString
        lock.lock()
        requests += 1
        lock.unlock()

        if let cachedData = cache.object(forKey: cacheKey) {
            lock.lock()
            hits += 1
            lock.unlock()
            return cachedData as Data
        }

        lock.lock()
        misses += 1
        lock.unlock()

        guard let generatedData = Self.generateThumbnailData(for: imageURL, maxPixelSize: maxPixelSize) else {
            return nil
        }

        cache.setObject(generatedData as NSData, forKey: cacheKey, cost: generatedData.count)
        lock.lock()
        trackedKeys.insert(cacheKeyString)
        lock.unlock()
        return generatedData
    }

    nonisolated func statsSnapshot() -> ThumbnailCacheStats {
        lock.lock()
        defer { lock.unlock() }

        return ThumbnailCacheStats(
            requests: requests,
            hits: hits,
            misses: misses,
            trackedEntries: trackedKeys.count
        )
    }

    nonisolated func resetStats() {
        lock.lock()
        requests = 0
        hits = 0
        misses = 0
        trackedKeys.removeAll(keepingCapacity: false)
        lock.unlock()
        cache.removeAllObjects()
    }

    nonisolated private static func generateThumbnailData(for imageURL: URL, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        // Center-crop to square so grid thumbnails always fill their tile bounds.
        let outputImage = centerCroppedSquare(from: cgImage) ?? cgImage
        let bitmapRep = NSBitmapImageRep(cgImage: outputImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    nonisolated private static func centerCroppedSquare(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let side = min(width, height)
        guard side > 0 else {
            return nil
        }

        let x = (width - side) / 2
        let y = (height - side) / 2
        let cropRect = CGRect(x: x, y: y, width: side, height: side)
        return image.cropping(to: cropRect)
    }
}
