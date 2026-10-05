import Foundation

/// Where the offline copy of the household's data lives, and how it is protected.
///
/// The copy holds notes, schedules and household details, so it is kept in its own folder that is
/// readable only while the device is unlocked and is left out of backups, rather than in the shared
/// Application Support folder where SwiftData would put it by default.
enum LocalStoreLocation {
    static let folderName = "BeaconCache"
    static let fileName = "Cache.store"

    /// The store file's URL, with its folder created and protected.
    static func prepare(in base: URL) throws -> URL {
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            // New files made inside inherit this: readable only while the device is unlocked.
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        // Set again on a folder that already existed (and ignored where the system has no such
        // protection, as on a Mac running the checks). Failing to protect the cache is not a reason
        // to lose it.
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = folder
        try mutable.setResourceValues(values)
        return folder.appendingPathComponent(fileName)
    }

    /// The unprotected store earlier versions kept in the shared folder. Only a cache, so it is
    /// removed rather than moved; the next refresh fills the new one.
    static func removeLegacyStore(in base: URL) {
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: base.appendingPathComponent(name))
        }
    }
}
