import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reading Crouton exports off the device: finding the files, decoding them, and shrinking their
/// photos. Nothing here touches the network, so it can be checked on its own.
enum CroutonImport {
    static let fileExtension = "crumb"

    /// Turns what was picked into the recipe files to import. A folder contributes every `.crumb`
    /// file inside it (any depth); a file picked by hand is taken as it is. Sorted by name so progress
    /// reads in a steady order. The caller must already have security-scoped access to each URL.
    static func crumbFiles(in urls: [URL]) -> [URL] {
        var found: [URL] = []
        var seen = Set<String>()
        func add(_ url: URL) {
            if seen.insert(url.standardizedFileURL.path).inserted { found.append(url) }
        }

        for url in urls {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else {
                add(url)
                continue
            }
            let walker = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            while let item = walker?.nextObject() as? URL {
                if item.pathExtension.lowercased() == fileExtension { add(item) }
            }
        }
        return found.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    static func parse(_ url: URL) throws -> CroutonRecipeFile {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try JSONDecoder().decode(CroutonRecipeFile.self, from: data)
    }

    /// A JPEG of the photo no larger than `maxPixelSize` on its long side. Crouton photos run up to
    /// several megabytes; a recipe card needs a few hundred kilobytes, and the server will not take
    /// more than five. Never scales a small photo up, and applies the photo's rotation.
    static func photoJPEG(fromBase64 base64: String, maxPixelSize: Int = 1600, quality: Double = 0.82) -> Data? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maxPixelSize
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maxPixelSize
        let longSide = min(maxPixelSize, max(width, height))

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longSide,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
