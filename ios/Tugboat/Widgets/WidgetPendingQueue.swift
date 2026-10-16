import Foundation
import Darwin

/// A widget tap that has been shown but not yet accepted by the server, kept so it can be sent when there is
/// a connection. Foundation only, so the rules can be checked from the command line (`ios/checks/widgets`).
struct WidgetPendingAction: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var action: String
    var itemId: String
    var userId: String
    var householdId: String
    var localDate: String
    /// A chore's period, kept so the write can be built without the snapshot (which the app may have rebuilt).
    var periodKey: String?
    var tappedAt: Date
    /// When a sender took this to send it. Another sender leaves it alone for `claimWindow`, so a tap isn't
    /// sent twice at once, and takes it up again if the first one never finished.
    var claimedAt: Date?

    /// The same limit the server puts on how old an end time may be.
    static let maxAge: TimeInterval = 24 * 60 * 60
    static let claimWindow: TimeInterval = 60
    /// A tap sent this soon after it was made uses the server's clock; a later one sends the time it was made.
    static let sendsTapTimeAfter: TimeInterval = 30

    static func make(action: String, itemId: String, in snapshot: WidgetSnapshot, now: Date = .now) -> WidgetPendingAction? {
        var periodKey: String?
        switch action {
        case "step": guard snapshot.steps.contains(where: { $0.id == itemId }) else { return nil }
        case "chore":
            guard let chore = snapshot.chores.first(where: { $0.id == itemId }) else { return nil }
            periodKey = chore.periodKey
        case "endSleep": guard snapshot.sleeps.contains(where: { $0.id == itemId && $0.end == nil }) else { return nil }
        default: return nil
        }
        return .init(id: UUID().uuidString, action: action, itemId: itemId, userId: snapshot.userId, householdId: snapshot.householdId,
                     localDate: snapshot.localDate, periodKey: periodKey, tappedAt: now, claimedAt: nil)
    }

    func isExpired(at now: Date) -> Bool { now.timeIntervalSince(tappedAt) > Self.maxAge }
    func isClaimed(at now: Date) -> Bool { claimedAt.map { now.timeIntervalSince($0) < Self.claimWindow } ?? false }

    /// What to send. End Sleep carries the time it was tapped once it is being sent late, so a delayed sync
    /// doesn't make the sleep look longer than it was.
    func writeRequest(now: Date = .now) -> WidgetWriteRequest? {
        switch action {
        case "step":
            return .init(path: "/api/mobile/v1/routines/toggle-step", body: WidgetStepBody(stepId: itemId, localDate: localDate, completed: true))
        case "chore":
            guard let periodKey else { return nil }
            return .init(path: "/api/mobile/v1/chores/toggle", body: WidgetChoreBody(choreId: itemId, periodKey: periodKey, completed: true))
        case "endSleep":
            let late = now.timeIntervalSince(tappedAt) > Self.sendsTapTimeAfter
            return .init(path: "/api/mobile/v1/naps",
                         body: WidgetEndSleepBody(action: "end", napId: itemId, endedAt: late ? Self.iso(tappedAt) : nil))
        default: return nil
        }
    }

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// The waiting taps, in a file in the App Group so the widget and the app share them. Every change is a
/// locked read, edit and write, because the two processes can both be at it.
struct WidgetPendingQueue: Sendable {
    private let directory: URL?

    init(directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.group)) {
        self.directory = directory
    }

    private var folder: URL? { directory?.appendingPathComponent("Library", isDirectory: true) }
    private var file: URL? { folder?.appendingPathComponent("widget-pending.json") }
    private var lockFile: URL? { folder?.appendingPathComponent("widget-pending.lock") }

    func load() -> [WidgetPendingAction] {
        locked { $0 }
    }

    /// Adds a tap unless the same item is already waiting (a second tap changes nothing). True if it was added.
    @discardableResult
    func enqueue(_ action: WidgetPendingAction) -> Bool {
        var added = false
        _ = locked { items in
            guard !items.contains(where: { $0.action == action.action && $0.itemId == action.itemId && $0.userId == action.userId }) else { return items }
            added = true
            return items + [action]
        }
        return added
    }

    /// The taps this sender should send now, oldest first: not expired and not taken by another sender in the
    /// last minute. They are marked as taken. Expired ones are dropped (the app will reconcile from the server).
    func claim(userId: String, now: Date = .now) -> [WidgetPendingAction] {
        var mine: [WidgetPendingAction] = []
        _ = locked { items in
            var result = items.filter { !$0.isExpired(at: now) }
            for index in result.indices where result[index].userId == userId && !result[index].isClaimed(at: now) {
                result[index].claimedAt = now
                mine.append(result[index])
            }
            return result
        }
        return mine.sorted { $0.tappedAt < $1.tappedAt }
    }

    func remove(id: String) {
        _ = locked { $0.filter { $0.id != id } }
    }

    /// Lets another sender take it: the send could not be made (offline), so it must stay.
    func release(id: String) {
        _ = locked { items in
            items.map { var item = $0; if item.id == id { item.claimedAt = nil }; return item }
        }
    }

    func clear() {
        _ = locked { _ in [] }
    }

    /// How many taps are waiting for this person, for the widget's "Waiting to sync".
    func count(userId: String, now: Date = .now) -> Int {
        load().filter { $0.userId == userId && !$0.isExpired(at: now) }.count
    }

    /// The snapshot with every waiting tap applied, for whoever rebuilds the snapshot from server data that
    /// doesn't have them yet; otherwise a refresh would show the item as undone until it syncs.
    func overlay(on snapshot: WidgetSnapshot, now: Date = .now) -> WidgetSnapshot {
        var result = snapshot
        for item in load() where item.userId == snapshot.userId && item.householdId == snapshot.householdId && !item.isExpired(at: now) {
            result = WidgetActionPolicy.applying(action: item.action, itemId: item.itemId, to: result, at: item.tappedAt)
        }
        return result
    }

    // MARK: Storage

    private func locked(_ edit: ([WidgetPendingAction]) -> [WidgetPendingAction]) -> [WidgetPendingAction] {
        guard let folder, let file, let lockFile else { return [] }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(lockFile.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return [] }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN); close(descriptor) }
        let current = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([WidgetPendingAction].self, from: $0) } ?? []
        let edited = edit(current)
        if edited != current {
            if let data = try? JSONEncoder().encode(edited) {
                #if os(iOS)
                try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                #else
                try? data.write(to: file, options: .atomic)
                #endif
            }
        }
        return edited
    }
}

/// Whether a failed request means there was no connection (so the tap should wait) rather than the server
/// refusing it (so the tap should be undone).
enum WidgetNetworkFailure {
    static func isOffline(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
