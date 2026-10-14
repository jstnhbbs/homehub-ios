import Foundation

struct Chore: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var profileId: String?
    var title: String
    var cadence: ChoreCadence
    var days: String
    var sortOrder: Int
    /// The day a one-off is due, or the day a repeating chore starts and counts from ("YYYY-MM-DD").
    var dueDate: String?
    /// "HH:mm" in the household's time zone.
    var dueTime: String?
    var repeatUnit: ChoreRepeatUnit?
    var repeatInterval: Int?
    var createdAt: Date?
    var updatedAt: Date?
}

struct ChoreRow: Codable, Identifiable, Sendable {
    let id: String
    var title: String
    var profileId: String?
    var cadence: ChoreCadence
    var days: String
    var sortOrder: Int?
    var dueDate: String?
    var dueTime: String?
    /// Nil from a server that predates repeat rules; `ChoreHelpers.repeatRule` falls back to `cadence`.
    var repeatUnit: ChoreRepeatUnit?
    var repeatInterval: Int?
    var periodKey: String
    var completed: Bool
    var completedAt: Date?
    var completedByName: String?
    var dueToday: Bool?
    var overdue: Bool?
    /// For a chore not due today, the next day it is ("YYYY-MM-DD").
    var nextDueDate: String?
}

struct ChoreInput: Codable, Sendable {
    var title: String
    var profileId: String?
    /// Always sent (daily for a daily chore, weekly for anything else) so a server that predates
    /// repeat rules can still read the chore.
    var cadence: ChoreCadence
    var repeatUnit: ChoreRepeatUnit?
    var repeatInterval: Int?
    var weekDay: String?
    /// Limits a daily chore to these weekdays (0 = Sunday), as "Weekdays" does.
    var weekdays: [String]?
    var dueDate: String?
    var dueTime: String?
}

struct ToggleChoreRequest: Codable, Sendable {
    var choreId: String
    var periodKey: String
    /// The state wanted, so a repeated request can't flip it back. Servers that predate this
    /// ignore it and flip the chore.
    var completed: Bool?
}

/// A chore with a time on one of the next few days. The dashboard sends these so a reminder can
/// be scheduled before the day arrives, without the app having to be opened first.
struct UpcomingChore: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var profileId: String?
    /// The day it falls on ("YYYY-MM-DD").
    var date: String
    /// "HH:mm" in the household's time zone.
    var dueTime: String
    var periodKey: String
}
