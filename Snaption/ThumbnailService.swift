import AppKit
import Foundation
import ImageIO

final class ThumbnailService: @unchecked Sendable {
    private let cache = NSCache<NSString, NSData>()

    init() {
        cache.countLimit = 1200
    }

    func thumbnailData(for imageURL: URL, maxPixelSize: Int) -> Data? {
        let cacheKey = "\(imageURL.path)#\(maxPixelSize)" as NSString
        if let cachedData = cache.object(forKey: cacheKey) {
            return cachedData as Data
        }

        guard let generatedData = Self.generateThumbnailData(for: imageURL, maxPixelSize: maxPixelSize) else {
            return nil
        }

        cache.setObject(generatedData as NSData, forKey: cacheKey)
        return generatedData
    }

    private static func generateThumbnailData(for imageURL: URL, maxPixelSize: Int) -> Data? {
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

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
