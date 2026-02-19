import AppKit
import Foundation
import ImageIO

actor ThumbnailService {
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 1200
    }

    func thumbnail(for imageURL: URL, maxPixelSize: Int) async -> NSImage? {
        let cacheKey = "\(imageURL.path)#\(maxPixelSize)" as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        let image = await Task.detached(priority: .utility) {
            Self.generateThumbnail(for: imageURL, maxPixelSize: maxPixelSize)
        }.value

        if let image {
            cache.setObject(image, forKey: cacheKey)
        }

        return image
    }

    private static func generateThumbnail(for imageURL: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }
}
