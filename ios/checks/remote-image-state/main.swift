import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

let first = RemoteImageRequest(url: URL(string: "https://example.com/old.jpg")!, maxPixelSize: 800)
let second = RemoteImageRequest(url: URL(string: "https://example.com/new.jpg")!, maxPixelSize: 800)
let larger = RemoteImageRequest(url: first.url, maxPixelSize: 1600)
var state = RemoteImageState<String>()
state.begin(first, cachedImage: "old photo")
check("a cached photo displays immediately", state.image(for: first) == "old photo")
check("a changed URL never displays the previous photo", state.image(for: second) == nil)
check("a changed decode size never displays the old-size photo", state.image(for: larger) == nil)
state.begin(second, cachedImage: nil)
check("uncached replacement displays its placeholder", state.image(for: second) == nil)
state.finish("late old photo", for: first, isCancelled: false)
check("an old request cannot populate the replacement", state.image(for: second) == nil)
state.finish("new photo", for: second, isCancelled: false)
check("the replacement displays when it finishes", state.image(for: second) == "new photo")
state.finish("late old photo", for: first, isCancelled: false)
check("an old request cannot overwrite a finished replacement", state.image(for: second) == "new photo")
state.begin(larger, cachedImage: "large cached photo")
check("the new decode size uses its own cached result", state.image(for: larger) == "large cached photo")
state.finish("cancelled photo", for: larger, isCancelled: true)
check("a cancelled task cannot overwrite the current photo", state.image(for: larger) == "large cached photo")
state.clear()
state.finish("late photo after scrolling away", for: larger, isCancelled: false)
check("a late completion cannot repopulate an offscreen view", state.image(for: larger) == nil)
state.begin(larger, cachedImage: nil)
state.finish("corrupt image", for: larger, isCancelled: true)
check("cancelled loading leaves the placeholder", state.image(for: larger) == nil)
state.finish(nil, for: larger, isCancelled: false)
check("failed loading leaves the placeholder", state.image(for: larger) == nil)

final class Photo {}
var photos = RemoteImageState<Photo>()
weak var retained: Photo?
do {
    let photo = Photo()
    retained = photo
    photos.begin(first, cachedImage: photo)
}
check("the visible view owns its decoded photo", retained != nil)
photos.begin(second, cachedImage: nil)
check("changing URLs releases the old view-owned photo", retained == nil)
do {
    let photo = Photo()
    retained = photo
    photos.finish(photo, for: second, isCancelled: false)
}
photos.clear()
check("scrolling away releases the view-owned photo", retained == nil)

if failures > 0 { exit(1) }
print("all passed")
