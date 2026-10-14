import CoreGraphics
import Foundation

/// The arithmetic behind cropping a photo to a square: a window of `cropSide` points that the
/// photo sits behind, which can be zoomed and dragged but never moved so far that the window
/// shows empty space. Foundation and CoreGraphics only, so it can be checked from the command line
/// (`ios/checks/photo-crop`).
struct PhotoCropGeometry: Equatable, Sendable {
    /// The photo's size (any unit, as long as `cropRect` is used in the same one).
    let imageSize: CGSize
    /// The side of the square window on screen, in points.
    let cropSide: CGFloat

    static let maxZoom: CGFloat = 5

    /// 1 is the photo just covering the window; larger is closer in.
    private(set) var zoom: CGFloat = 1
    /// How far the photo's center is from the window's center, in points.
    private(set) var offset: CGSize = .zero

    init(imageSize: CGSize, cropSide: CGFloat) {
        self.imageSize = imageSize
        self.cropSide = cropSide
    }

    /// Screen points per image unit at zoom 1: the shorter side of the photo fills the window.
    var baseScale: CGFloat {
        let shortest = min(imageSize.width, imageSize.height)
        return shortest > 0 ? cropSide / shortest : 1
    }

    var scale: CGFloat { baseScale * zoom }

    /// The photo's size on screen.
    var displaySize: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    mutating func setZoom(_ value: CGFloat) {
        zoom = min(max(value, 1), Self.maxZoom)
        offset = clamped(offset)
    }

    mutating func setOffset(_ value: CGSize) {
        offset = clamped(value)
    }

    /// The offset moved back inside what keeps the window covered.
    func clamped(_ value: CGSize) -> CGSize {
        let limitX = max(0, (displaySize.width - cropSide) / 2)
        let limitY = max(0, (displaySize.height - cropSide) / 2)
        return CGSize(
            width: min(max(value.width, -limitX), limitX),
            height: min(max(value.height, -limitY), limitY)
        )
    }

    /// The part of the photo inside the window, in image units. Always inside the photo.
    func cropRect() -> CGRect {
        guard scale > 0 else { return CGRect(origin: .zero, size: imageSize) }
        let side = cropSide / scale
        let x = (displaySize.width / 2 - cropSide / 2 - offset.width) / scale
        let y = (displaySize.height / 2 - cropSide / 2 - offset.height) / scale
        let rect = CGRect(x: x, y: y, width: side, height: side)
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }
}
