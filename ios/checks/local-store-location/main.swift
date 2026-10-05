import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let fm = FileManager.default
let base = fm.temporaryDirectory.appendingPathComponent("store-location-\(UUID().uuidString)")
try fm.createDirectory(at: base, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: base) }

let url = try LocalStoreLocation.prepare(in: base)
check("the store sits in its own folder", url.deletingLastPathComponent().lastPathComponent, "BeaconCache")
check("with the expected file name", url.lastPathComponent, "Cache.store")
var isDirectory: ObjCBool = false
check("the folder exists", String(fm.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &isDirectory) && isDirectory.boolValue), "true")
let excluded = try url.deletingLastPathComponent().resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
check("the folder is left out of backups", String(excluded ?? false), "true")

// Preparing again, as every launch does, changes nothing and does not fail.
let again = try LocalStoreLocation.prepare(in: base)
check("preparing twice gives the same place", again.path, url.path)

// A store left by earlier versions is removed, and other files are left alone.
for name in ["default.store", "default.store-shm", "default.store-wal", "keep.me"] {
    try Data("x".utf8).write(to: base.appendingPathComponent(name))
}
LocalStoreLocation.removeLegacyStore(in: base)
check("the old store files are gone",
      ["default.store", "default.store-shm", "default.store-wal"].map { String(fm.fileExists(atPath: base.appendingPathComponent($0).path)) }.joined(separator: ","),
      "false,false,false")
check("nothing else is touched", String(fm.fileExists(atPath: base.appendingPathComponent("keep.me").path)), "true")
LocalStoreLocation.removeLegacyStore(in: base)
check("removing when there is nothing to remove is fine", String(fm.fileExists(atPath: base.appendingPathComponent("keep.me").path)), "true")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
