import Foundation
import UIKit

enum ProfilePhotoHelpers {
    static let maxBytes = 5 * 1024 * 1024

    static func hasPhoto(_ avatar: String?) -> Bool {
        guard let avatar, let url = URL(string: avatar) else { return false }
        if url.host?.contains("blob.vercel-storage.com") == true {
            return url.path.contains("/profiles/") || url.path.contains("/households/")
        }
        if url.path.contains("/profile-photos/") || url.path.contains("/household-photos/") {
            return true
        }
        return false
    }

    /// A picked photo ready for cropping: upright (the camera's rotation applied to the pixels, so
    /// the crop rectangle and what is on screen agree) and no larger than `maxDimension` on a side,
    /// which keeps a 48-megapixel photo from filling memory while it is being moved around.
    static func cropSource(from data: Data, maxDimension: CGFloat = 3000) -> UIImage? {
        guard maxDimension.isFinite, maxDimension >= 1,
              let thumbnail = ImageDownsampling.thumbnail(from: data, maxPixelSize: Int(maxDimension)) else { return nil }
        let image = UIImage(cgImage: thumbnail, scale: 1, orientation: .up)
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > 0 else { return nil }
        let factor = min(1, maxDimension / largest)
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// The part of an upright photo (`cropSource`) inside `rect`, in the photo's pixels.
    static func cropped(_ image: UIImage, to rect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let pixels = rect.integral.intersection(bounds)
        guard !pixels.isNull, pixels.width >= 1, pixels.height >= 1,
              let piece = cgImage.cropping(to: pixels) else { return image }
        return UIImage(cgImage: piece, scale: 1, orientation: .up)
    }

    static func prepareUploadData(from image: UIImage) -> (data: Data, mimeType: String, fileName: String)? {
        if let jpeg = compress(image: image, mimeType: "image/jpeg", quality: 0.85) {
            return jpeg
        }
        return nil
    }

    /// A view's async task still resumes on MainActor. Keep the synchronous ImageIO/UIKit work
    /// on a worker, and discard results if the originating picker or upload has been cancelled.
    static func cropSourceInBackground(from data: Data) async throws -> UIImage? {
        try await process { cropSource(from: data) }
    }

    static func prepareUploadDataInBackground(from image: UIImage) async throws -> (data: Data, mimeType: String, fileName: String)? {
        try await process { prepareUploadData(from: image) }
    }

    private static func process<Value: Sendable>(_ operation: @escaping @Sendable () -> Value) async throws -> Value {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return autoreleasepool(invoking: operation)
        }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
        }
    }

    private static func compress(
        image: UIImage,
        mimeType: String,
        quality: CGFloat
    ) -> (data: Data, mimeType: String, fileName: String)? {
        let maxDimension: CGFloat = 1600
        let scaled = downscale(image: image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        guard data.count <= maxBytes else {
            if quality > 0.4 {
                return compress(image: scaled, mimeType: mimeType, quality: quality - 0.15)
            }
            return nil
        }
        return (data, "image/jpeg", "profile-photo.jpg")
    }

    private static func downscale(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        // Upload dimensions are pixels, not display points on a 2x or 3x screen.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
