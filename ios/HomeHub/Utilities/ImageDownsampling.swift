import CoreGraphics
import Foundation
import ImageIO

enum ImageDownsampling {
    /// The image scaled down so its longest side is at most `maxPixelSize`, decoded and ready to draw,
    /// with its orientation applied. A smaller image is returned at its own size, never enlarged.
    ///
    /// Recipe photos are stored at up to 1600 pixels, which is about 7 MB once decoded, and a card
    /// shows them a few hundred points wide. Decoding at the size shown keeps a long list light, and
    /// because the decode happens here, not when the image is first drawn, it can run off the main
    /// thread.
    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize, max(width, height)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Memory a decoded image takes, for sizing a cache.
    static func decodedByteCount(width: Int, height: Int) -> Int {
        width * height * 4
    }
}
