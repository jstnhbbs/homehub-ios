import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// MARK: Decoding a file

/// A tiny but real JPEG, as base64, the way Crouton stores a photo.
func makeJPEG(width: Int, height: Int) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.7, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
    let image = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    CGImageDestinationFinalize(destination)
    return data as Data
}

func dimensions(of jpeg: Data) -> (Int, Int)? {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = props[kCGImagePropertyPixelWidth] as? Int,
          let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return (w, h)
}

let bigPhoto = makeJPEG(width: 3000, height: 2000)
let smallPhoto = makeJPEG(width: 400, height: 300)

let exportJSON = """
{
  "uuid": "DB0AAC6C-F0F0-43AE-886B-3A715C3A1230",
  "name": "Test Chili",
  "serves": 4,
  "duration": 15,
  "cookingDuration": 20,
  "defaultScale": 1.9999999403953552,
  "rating": 0,
  "isPublicRecipe": false,
  "folderIDs": [],
  "webLink": "https://example.com/chili",
  "sourceName": "example.com",
  "neutritionalInfo": "Fat: 31 g\\nCalories: 489 kcal",
  "sourceImage": "THUMBNAIL-SHOULD-BE-IGNORED",
  "images": ["\(bigPhoto.base64EncodedString())"],
  "tags": [{"uuid": "t", "color": "#FCBE56", "name": "Chicken"}],
  "ingredients": [
    {"uuid": "i1", "order": 0, "ingredient": {"uuid": "x", "name": "chicken broth"}, "quantity": {"quantityType": "CUP", "amount": 5, "secondaryAmount": 6}},
    {"uuid": "i2", "order": 1, "ingredient": {"uuid": "y", "name": "salt"}},
    {"uuid": "i3", "order": 2, "ingredient": {"uuid": "z", "name": "Gravy"}, "quantity": {"quantityType": "SECTION"}}
  ],
  "steps": [
    {"uuid": "s1", "order": 0, "isSection": true, "step": "Stove"},
    {"uuid": "s2", "order": 1, "isSection": false, "step": "1. Simmer."}
  ]
}
"""

let decoded = try JSONDecoder().decode(CroutonRecipeFile.self, from: Data(exportJSON.utf8))
check("the id and name", "\(decoded.recipe.uuid) | \(decoded.recipe.name)", "DB0AAC6C-F0F0-43AE-886B-3A715C3A1230 | Test Chili")
check("servings and times", "\(decoded.recipe.serves ?? -1) \(decoded.recipe.duration ?? -1) \(decoded.recipe.cookingDuration ?? -1)", "4.0 15.0 20.0")
check("a range keeps both ends", "\(decoded.recipe.ingredients[0].quantity?.amount ?? -1)-\(decoded.recipe.ingredients[0].quantity?.secondaryAmount ?? -1)", "5.0-6.0")
check("an ingredient with no quantity", String(decoded.recipe.ingredients[1].quantity == nil), "true")
check("a section row keeps its marker", decoded.recipe.ingredients[2].quantity?.quantityType ?? "", "SECTION")
check("steps and their section flag", "\(decoded.recipe.steps.map { $0.isSection ?? false })", "[true, false]")
check("tags", decoded.recipe.tags?.map(\.name).joined(separator: ",") ?? "", "Chicken")
check("the full photo is kept, not the thumbnail", String(decoded.photoBase64 == bigPhoto.base64EncodedString()), "true")

// What is sent leaves out the photo and anything Crouton-only, and omits what is empty.
let sent = String(data: try JSONEncoder().encode(CroutonImportRequest(recipes: [decoded.recipe])), encoding: .utf8)!
check("no photo in what is sent", String(sent.contains("images") || sent.contains("base64") || sent.contains("THUMBNAIL")), "false")
check("no Crouton-only fields in what is sent", String(sent.contains("defaultScale") || sent.contains("rating") || sent.contains("folderIDs")), "false")
check("the recipe text is in what is sent", String(sent.contains("\"chicken broth\"") && sent.contains("\"SECTION\"")), "true")
check("a missing optional is left out, not sent as null", String(sent.contains("null")), "false")

// A file with no photos and one with a different shape.
let noPhoto = try JSONDecoder().decode(CroutonRecipeFile.self, from: Data(#"{"uuid":"u","name":"n","ingredients":[],"steps":[],"images":[]}"#.utf8))
check("no photos", String(noPhoto.photoBase64 == nil), "true")
let noImagesKey = try JSONDecoder().decode(CroutonRecipeFile.self, from: Data(#"{"uuid":"u","name":"n","ingredients":[],"steps":[]}"#.utf8))
check("no images key at all", String(noImagesKey.photoBase64 == nil), "true")
var rejected = false
do { _ = try JSONDecoder().decode(CroutonRecipeFile.self, from: Data(#"{"hello":"world"}"#.utf8)) } catch { rejected = true }
check("something that isn't a Crouton recipe is refused", String(rejected), "true")

// MARK: The server's answer

let answer = try JSONDecoder().decode(CroutonImportResponse.self, from: Data("""
{"results":[{"index":0,"title":"A","status":"created","id":"x"},{"index":1,"title":"B","status":"duplicate","id":"y"},{"index":2,"title":"C","status":"failed","error":"uuid: Required"}],"created":1,"duplicates":1,"failed":1}
""".utf8))
check("the answer's counts", "\(answer.created) \(answer.duplicates) \(answer.failed)", "1 1 1")
check("each result's status", answer.results.map { $0.status.rawValue }.joined(separator: ","), "created,duplicate,failed")
check("a failure's reason", answer.results[2].error ?? "", "uuid: Required")

// MARK: Photos

let big = CroutonImport.photoJPEG(fromBase64: bigPhoto.base64EncodedString())
check("a big photo is made smaller", String(big != nil), "true")
if let big, let size = dimensions(of: big) {
    check("keeping its shape, longest side 1600", "\(size.0)x\(size.1)", "1600x1067")
    check("as a JPEG", String(big.prefix(3).elementsEqual([0xff, 0xd8, 0xff])), "true")
    check("and well under the server's 5 MB", String(big.count < 1_000_000), "true")
} else {
    failures += 1
    print("FAIL could not read the resized photo")
}

let small = CroutonImport.photoJPEG(fromBase64: smallPhoto.base64EncodedString())
if let small, let size = dimensions(of: small) {
    check("a small photo is not scaled up", "\(size.0)x\(size.1)", "400x300")
} else {
    failures += 1
    print("FAIL could not read the small photo")
}

let custom = CroutonImport.photoJPEG(fromBase64: bigPhoto.base64EncodedString(), maxPixelSize: 800)
check("another size limit", String(dimensions(of: custom ?? Data()).map { max($0.0, $0.1) } ?? -1), "800")
check("text that isn't base64", String(CroutonImport.photoJPEG(fromBase64: "not an image!!") == nil), "true")
check("base64 of something that isn't an image", String(CroutonImport.photoJPEG(fromBase64: Data("hello".utf8).base64EncodedString()) == nil), "true")
check("nothing at all", String(CroutonImport.photoJPEG(fromBase64: "") == nil), "true")
let wrapped = bigPhoto.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
check("base64 broken into lines still reads", String(CroutonImport.photoJPEG(fromBase64: wrapped) != nil), "true")

// MARK: Finding the files

let root = FileManager.default.temporaryDirectory.appendingPathComponent("crouton-check-\(UUID().uuidString)")
let fm = FileManager.default
try fm.createDirectory(at: root.appendingPathComponent("Crouton Recipes/Sub"), withIntermediateDirectories: true)
for name in ["Banana Bread.crumb", "apple pie.CRUMB", "Recipe 10.crumb", "Recipe 2.crumb", "notes.txt", ".hidden.crumb"] {
    try Data(#"{"uuid":"u","name":"n","ingredients":[],"steps":[]}"#.utf8).write(to: root.appendingPathComponent("Crouton Recipes/\(name)"))
}
try Data(#"{"uuid":"u2","name":"n2","ingredients":[],"steps":[]}"#.utf8).write(to: root.appendingPathComponent("Crouton Recipes/Sub/Nested.crumb"))
let loose = root.appendingPathComponent("renamed.json")
try Data(#"{"uuid":"u3","name":"n3","ingredients":[],"steps":[]}"#.utf8).write(to: loose)

let folderFiles = CroutonImport.crumbFiles(in: [root.appendingPathComponent("Crouton Recipes")])
check("a folder gives its .crumb files at any depth, in natural order, ignoring others and hidden ones",
      folderFiles.map(\.lastPathComponent).joined(separator: ", "),
      "apple pie.CRUMB, Banana Bread.crumb, Nested.crumb, Recipe 2.crumb, Recipe 10.crumb")
check("a file picked by hand is taken whatever it's called", CroutonImport.crumbFiles(in: [loose]).map(\.lastPathComponent).joined(), "renamed.json")
let both = CroutonImport.crumbFiles(in: [root.appendingPathComponent("Crouton Recipes"), root.appendingPathComponent("Crouton Recipes/Banana Bread.crumb")])
check("the same file reached twice counts once", String(both.count), "5")
check("nothing picked", String(CroutonImport.crumbFiles(in: []).count), "0")
check("a missing path", String(CroutonImport.crumbFiles(in: [root.appendingPathComponent("nope")]).count), "1")
check("parsing a file from disk", (try? CroutonImport.parse(loose))?.recipe.uuid ?? "failed", "u3")
let notJSON = root.appendingPathComponent("junk.crumb")
try Data("not json".utf8).write(to: notJSON)
check("a file that isn't JSON fails to parse", String((try? CroutonImport.parse(notJSON)) == nil), "true")
check("a file that doesn't exist fails to parse", String((try? CroutonImport.parse(root.appendingPathComponent("gone.crumb"))) == nil), "true")
try? fm.removeItem(at: root)

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
