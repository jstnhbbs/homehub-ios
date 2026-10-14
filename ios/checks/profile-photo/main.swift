import Foundation
import UIKit

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
let format = UIGraphicsImageRendererFormat()
format.scale = 1
let large = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: format).image { context in
    UIColor.red.setFill()
    context.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
}
let data = large.jpegData(compressionQuality: 0.9)!
let crop = ProfilePhotoHelpers.cropSource(from: data)!
check("crop source is capped at 3000 pixels", crop.cgImage?.width == 3000 && crop.cgImage?.height == 2250)
check("crop source has upright pixel coordinates", crop.scale == 1 && crop.imageOrientation == .up)
let upload = ProfilePhotoHelpers.prepareUploadData(from: crop)!
let decoded = UIImage(data: upload.data)!
check("upload really is 1600 pixels regardless of screen scale", decoded.cgImage?.width == 1600 && decoded.cgImage?.height == 1200)
check("upload remains under the size limit", upload.data.count <= ProfilePhotoHelpers.maxBytes)
check("invalid picked data is refused", ProfilePhotoHelpers.cropSource(from: Data("not an image".utf8)) == nil)
check("invalid dimension is refused", ProfilePhotoHelpers.cropSource(from: data, maxDimension: .nan) == nil)
let square = ProfilePhotoHelpers.cropped(crop, to: CGRect(x: 400, y: 300, width: 1000, height: 1000))
check("cropping preserves square pixels", square.cgImage?.width == 1000 && square.cgImage?.height == 1000)
let small = UIImage(data: ProfilePhotoHelpers.prepareUploadData(from: square)!.data)!
check("small uploads are not enlarged", small.cgImage?.width == 1000)
if failures > 0 { exit(1) }
print("all passed")
