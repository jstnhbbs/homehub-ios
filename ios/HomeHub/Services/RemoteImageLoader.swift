import SwiftUI
import UIKit

/// Loads photos from the web for lists. `AsyncImage` has three problems for a long list of large
/// photos: the system's default URL cache is far too small to keep them (so scrolling back or
/// changing a filter downloads them again), it decodes each photo at full size, and it keeps every
/// decoded photo alive for as long as its row exists. This loader keeps its own bigger cache on disk,
/// decodes at the size shown (see `ImageDownsampling`), and holds decoded images in a bounded cache.
final class RemoteImageLoader: @unchecked Sendable {
    static let shared = RemoteImageLoader()

    private let session: URLSession
    private let memory = NSCache<NSString, UIImage>()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)
        memory.totalCostLimit = 96 * 1024 * 1024
    }

    private func key(_ url: URL, _ maxPixelSize: Int) -> NSString {
        "\(maxPixelSize)|\(url.absoluteString)" as NSString
    }

    /// The image if it has been loaded at this size recently. Cheap enough to call while drawing.
    func cachedImage(for url: URL, maxPixelSize: Int) -> UIImage? {
        memory.object(forKey: key(url, maxPixelSize))
    }

    /// Downloads (or reads from the disk cache) and decodes the image. Runs off the main thread and
    /// stops if the calling task is cancelled, so rows that scroll away don't keep downloading.
    func image(for url: URL, maxPixelSize: Int) async -> UIImage? {
        if let hit = cachedImage(for: url, maxPixelSize: maxPixelSize) { return hit }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            try Task.checkCancellation()
            guard let cgImage = ImageDownsampling.thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
            let image = UIImage(cgImage: cgImage)
            memory.setObject(
                image,
                forKey: key(url, maxPixelSize),
                cost: ImageDownsampling.decodedByteCount(width: cgImage.width, height: cgImage.height)
            )
            return image
        } catch {
            return nil
        }
    }
}

/// A photo from the web, filled to its frame. Shows `placeholder` until it arrives or if it can't be
/// loaded. The decoded image is let go when the view leaves the screen (it stays in the loader's
/// bounded cache), so a long list doesn't hold every photo in memory.
struct RemoteImage<Placeholder: View>: View {
    let url: URL
    /// Longest side to decode, in pixels (points times the screen scale).
    var maxPixelSize: Int = 800
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(url: URL, maxPixelSize: Int = 800, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
        // From the cache when it is there, so a row that is recreated doesn't flash its placeholder.
        _image = State(initialValue: RemoteImageLoader.shared.cachedImage(for: url, maxPixelSize: maxPixelSize))
    }

    var body: some View {
        // The photo is drawn over an empty view that takes whatever size it is given. A photo scaled
        // to fill is bigger than its frame; clipping hides the extra but does not stop it taking
        // touches, so on its own a tall photo sat invisibly over the controls above its card and
        // swallowed their taps (a filter chip that would not switch off, an Add button that barely
        // answered). The photo takes no touches itself, and the frame is the touch area.
        Color.clear
            .overlay {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder()
                    }
                }
                .allowsHitTesting(false)
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: url) {
                guard image == nil else { return }
                if let cached = RemoteImageLoader.shared.cachedImage(for: url, maxPixelSize: maxPixelSize) {
                    image = cached
                } else {
                    image = await RemoteImageLoader.shared.image(for: url, maxPixelSize: maxPixelSize)
                }
            }
            .onDisappear { image = nil }
    }
}
