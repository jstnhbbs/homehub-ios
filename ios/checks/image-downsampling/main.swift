import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func makeJPEG(width: Int, height: Int, orientation: Int? = nil) -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
    if let orientation { properties[kCGImagePropertyOrientation] = orientation }
    CGImageDestinationAddImage(destination, context.makeImage()!, properties as CFDictionary)
    CGImageDestinationFinalize(destination)
    return data as Data
}

func size(_ image: CGImage?) -> String {
    image.map { "\($0.width)x\($0.height)" } ?? "nil"
}

// A recipe photo, 1600 wide as the app stores them.
let photo = makeJPEG(width: 1600, height: 1067)
check("a big photo is brought down to the size asked for", size(ImageDownsampling.thumbnail(from: photo, maxPixelSize: 800)), "800x533")
check("a card-sized request on a phone", size(ImageDownsampling.thumbnail(from: photo, maxPixelSize: 1100)), "1100x734")
check("asking for the full size gives the full size", size(ImageDownsampling.thumbnail(from: photo, maxPixelSize: 1600)), "1600x1067")

// Never enlarged.
let small = makeJPEG(width: 400, height: 300)
check("a small image is not scaled up", size(ImageDownsampling.thumbnail(from: small, maxPixelSize: 1100)), "400x300")
check("even when the request is far larger", size(ImageDownsampling.thumbnail(from: small, maxPixelSize: 5000)), "400x300")

// A portrait photo: the longest side is the one limited.
let tall = makeJPEG(width: 900, height: 1600)
check("a tall photo is limited on its height", size(ImageDownsampling.thumbnail(from: tall, maxPixelSize: 800)), "450x800")

// Phones store photos sideways with an orientation flag; the thumbnail is the right way up.
let sideways = makeJPEG(width: 1600, height: 1067, orientation: 6)
check("a photo flagged as rotated comes out upright", size(ImageDownsampling.thumbnail(from: sideways, maxPixelSize: 800)), "533x800")

// Things that are not images.
check("no data", size(ImageDownsampling.thumbnail(from: Data(), maxPixelSize: 800)), "nil")
check("text", size(ImageDownsampling.thumbnail(from: Data("not an image".utf8), maxPixelSize: 800)), "nil")
check("a size of zero", size(ImageDownsampling.thumbnail(from: photo, maxPixelSize: 0)), "nil")
check("a negative size", size(ImageDownsampling.thumbnail(from: photo, maxPixelSize: -5)), "nil")

// The cache is sized from what is really held in memory.
check("decoded size", String(ImageDownsampling.decodedByteCount(width: 1100, height: 734)), "3229600")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
