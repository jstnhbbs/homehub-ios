import Foundation
import UIKit

enum ProfilePhotoHelpers {
    static let maxBytes = 5 * 1024 * 1024

    static func hasPhoto(_ avatar: String?) -> Bool {
        guard let avatar, let url = URL(string: avatar) else { return false }
        if url.host?.contains("blob.vercel-storage.com") == true {
            return url.path.contains("/profiles/")
        }
        if url.path.contains("/profile-photos/") {
            return true
        }
        return false
    }

    static func prepareUploadData(from image: UIImage) -> (data: Data, mimeType: String, fileName: String)? {
        if let jpeg = compress(image: image, mimeType: "image/jpeg", quality: 0.85) {
            return jpeg
        }
        return nil
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
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
