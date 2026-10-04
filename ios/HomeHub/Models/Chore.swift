import Foundation

struct Chore: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var profileId: String?
    var title: String
    var cadence: ChoreCadence
    var days: String
    var sortOrder: Int
    /// Optional deadline ("YYYY-MM-DD"), independent of cadence — e.g. a one-off "due Friday" item.
    var dueDate: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct ChoreCompletion: Codable, Sendable {
    let choreId: String
    let periodKey: String
    var completedAt: Date
}

struct ChoreRow: Codable, Identifiable, Sendable {
    let id: String
    var title: String
    var profileId: String?
    var cadence: ChoreCadence
    var days: String
    var sortOrder: Int?
    var dueDate: String?
    var periodKey: String
    var completed: Bool
    var completedAt: Date?
    var completedByName: String?
    var dueToday: Bool?
    var overdue: Bool?
}

struct ChoreInput: Codable, Sendable {
    var title: String
    var profileId: String?
    var cadence: ChoreCadence
    var weekDay: String?
    var dueDate: String?
}

struct ToggleChoreRequest: Codable, Sendable {
    var choreId: String
    var periodKey: String
}
