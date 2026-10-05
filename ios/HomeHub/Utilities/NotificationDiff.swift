import Foundation

/// What a pending local notification says, reduced to what decides whether it needs replacing.
struct PlannedNotification: Equatable, Sendable {
    var id: String
    var title: String
    var body: String
    var thread: String
    /// When it fires, as text (year-month-day hour:minute and time zone).
    var trigger: String
}

/// Works out the least that has to change to turn the reminders that are scheduled into the ones
/// that are wanted. Rescheduling everything on every refresh meant clearing and re-adding dozens of
/// reminders one at a time after each check-off, even when nothing about them had changed.
enum NotificationDiff {
    struct Changes: Equatable, Sendable {
        /// Scheduled reminders that are no longer wanted.
        var remove: [String]
        /// Wanted reminders that are missing or differ from what is scheduled. Adding one with an id
        /// that already exists replaces it.
        var add: [String]
    }

    static func changes(existing: [PlannedNotification], desired: [PlannedNotification]) -> Changes {
        // If the same id is wanted twice, the later one is what ends up scheduled.
        var wanted: [String: PlannedNotification] = [:]
        var order: [String] = []
        for item in desired {
            if wanted[item.id] == nil { order.append(item.id) }
            wanted[item.id] = item
        }
        let scheduled = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        let remove = existing
            .map(\.id)
            .filter { wanted[$0] == nil }
        let removeUnique = Array(NSOrderedSet(array: remove)) as? [String] ?? remove
        let add = order.filter { scheduled[$0] != wanted[$0] }
        return Changes(remove: removeUnique, add: add)
    }
}
