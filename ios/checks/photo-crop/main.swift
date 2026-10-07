import CoreGraphics
import Foundation

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { print("ok   \(label)") } else { failures += 1; print("FAIL \(label) \(detail())") }
}
func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.001 }
func describe(_ r: CGRect) -> String { "x=\(r.minX) y=\(r.minY) w=\(r.width) h=\(r.height)" }

// A landscape photo, 4000 x 3000, in a 300-point window.
var g = PhotoCropGeometry(imageSize: CGSize(width: 4000, height: 3000), cropSide: 300)
check("zoom 1: the shorter side fills the window", near(g.baseScale, 0.1) && near(g.displaySize.height, 300) && near(g.displaySize.width, 400))
var r = g.cropRect()
check("zoom 1 starts as the centered square", near(r.minX, 500) && near(r.minY, 0) && near(r.width, 3000) && near(r.height, 3000), describe(r))

g.setOffset(CGSize(width: 1000, height: 1000))
check("a drag past the edge is held at the edge (landscape: sideways only)", near(g.offset.width, 50) && near(g.offset.height, 0), "\(g.offset)")
r = g.cropRect()
check("dragged right to the edge shows the photo's left edge", near(r.minX, 0), describe(r))
g.setOffset(CGSize(width: -1000, height: 0))
r = g.cropRect()
check("dragged left to the edge shows the photo's right edge", near(r.maxX, 4000), describe(r))

g = PhotoCropGeometry(imageSize: CGSize(width: 4000, height: 3000), cropSide: 300)
g.setZoom(2)
r = g.cropRect()
check("zoom 2 halves the crop and keeps it centered", near(r.width, 1500) && near(r.minX, 1250) && near(r.minY, 750), describe(r))
g.setOffset(CGSize(width: 10_000, height: 10_000))
r = g.cropRect()
check("zoomed and dragged to a corner stays inside the photo", near(r.minX, 0) && near(r.minY, 0) && near(r.width, 1500), describe(r))
g.setZoom(1)
r = g.cropRect()
check("zooming back out re-clamps the offset", near(g.offset.height, 0) && r.minX >= 0 && r.maxX <= 4000, "\(g.offset) \(describe(r))")

g.setZoom(50)
check("zoom is limited to the maximum", near(g.zoom, PhotoCropGeometry.maxZoom))
g.setZoom(0.2)
check("zoom cannot go below covering the window", near(g.zoom, 1))

// A portrait photo.
var p = PhotoCropGeometry(imageSize: CGSize(width: 1500, height: 2000), cropSide: 300)
r = p.cropRect()
check("portrait starts centered vertically", near(r.minX, 0) && near(r.minY, 250) && near(r.width, 1500), describe(r))
p.setOffset(CGSize(width: 500, height: -10_000))
check("portrait drag is vertical only", near(p.offset.width, 0) && p.offset.height < 0, "\(p.offset)")
r = p.cropRect()
check("portrait dragged up to the edge shows the bottom", near(r.maxY, 2000), describe(r))

// A square photo, and a photo smaller than the window.
let sq = PhotoCropGeometry(imageSize: CGSize(width: 800, height: 800), cropSide: 300)
check("a square photo is cropped whole", describe(sq.cropRect()) == describe(CGRect(x: 0, y: 0, width: 800, height: 800)), describe(sq.cropRect()))
var small = PhotoCropGeometry(imageSize: CGSize(width: 100, height: 150), cropSide: 300)
small.setZoom(3)
small.setOffset(CGSize(width: 9999, height: -9999))
let sr = small.cropRect()
check("a photo smaller than the window still crops inside itself", sr.minX >= 0 && sr.minY >= 0 && sr.maxX <= 100 && sr.maxY <= 150 && sr.width > 0, describe(sr))

// Always inside, for many combinations.
var inside = true
for zoom in stride(from: 1.0, through: 5.0, by: 0.5) {
    for dx in stride(from: -2000.0, through: 2000.0, by: 400) {
        for dy in stride(from: -2000.0, through: 2000.0, by: 400) {
            var t = PhotoCropGeometry(imageSize: CGSize(width: 3024, height: 4032), cropSide: 280)
            t.setZoom(CGFloat(zoom)); t.setOffset(CGSize(width: dx, height: dy))
            let c = t.cropRect()
            if c.minX < -0.001 || c.minY < -0.001 || c.maxX > 3024.001 || c.maxY > 4032.001 || abs(c.width - c.height) > 0.01 { inside = false }
        }
    }
}
check("the crop stays inside the photo and square, for every zoom and drag", inside)

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall photo crop checks passed")
