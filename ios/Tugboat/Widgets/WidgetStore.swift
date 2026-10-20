import Foundation

/// How the widget tells the app it changed something on the server. The app is often running in the
/// background (or even in front) with a copy of the data that doesn't have the change yet, and the widget
/// is a separate process, so it leaves a timestamp in the shared defaults (read when the app comes to
/// the front) and posts a system-wide notification (heard right away if the app is running).
enum WidgetWriteSignal {
    static let darwinName = "com.tugboatfamily.app.widget-wrote"
    private static let key = "tugboat.widget.lastWriteAt"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetStore.group) }

    static var lastWriteAt: Date? { defaults?.object(forKey: key) as? Date }

    static func recordWrite() {
        defaults?.set(Date(), forKey: key)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(darwinName as CFString), nil, nil, true)
    }
}

struct WidgetStore: Sendable {
    static let group = "group.com.tugboatfamily.app"
    private let directory: URL?

    init(directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)) {
        self.directory = directory
    }
    private var file: URL? { directory?.appendingPathComponent("household-widget-v1.json") }

    func load() -> WidgetSnapshot? {
        guard let file, let data = try? Data(contentsOf: file),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data), snapshot.version == 1 else { return nil }
        return snapshot
    }
    @discardableResult
    func save(_ snapshot: WidgetSnapshot, force: Bool = false) -> Bool {
        guard let file, let data = try? JSONEncoder().encode(snapshot) else { return false }
        // Don't wake WidgetKit or rewrite its file on every equal dashboard refresh.
        if !force, var previous = load() {
            previous.updatedAt = snapshot.updatedAt
            if previous == snapshot, let onDisk = load(), snapshot.updatedAt.timeIntervalSince(onDisk.updatedAt) < 900 { return false }
        }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: file, options: .atomic)
            #endif
            return true
        } catch {
            NSLog("Tugboat: couldn't save widget snapshot: %@", error.localizedDescription)
            return false
        }
    }
    func clear() {
        guard let file else { return }
        try? FileManager.default.removeItem(at: file)
    }
}
