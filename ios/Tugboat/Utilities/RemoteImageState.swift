import Foundation

struct RemoteImageRequest: Hashable, Sendable {
    let url: URL
    let maxPixelSize: Int
}

/// A reused photo view may keep its state while its URL or decode size changes.
struct RemoteImageState<Image> {
    private var request: RemoteImageRequest?
    private var loadedImage: Image?

    mutating func begin(_ request: RemoteImageRequest, cachedImage: Image?) {
        self.request = request
        loadedImage = cachedImage
    }

    func image(for request: RemoteImageRequest) -> Image? {
        self.request == request ? loadedImage : nil
    }

    mutating func finish(_ image: Image?, for request: RemoteImageRequest, isCancelled: Bool) {
        guard !isCancelled, self.request == request else { return }
        loadedImage = image
    }

    mutating func clear() {
        request = nil
        loadedImage = nil
    }
}
