import Foundation

struct Chore: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var profileId: String?
    var title: String
    var cadence: ChoreCadence
    var days: String
    var sortOrder: Int
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
    var periodKey: String
    var completed: Bool
    var dueToday: Bool?
}

struct ChoreInput: Codable, Sendable {
    var title: String
    var profileId: String?
    var cadence: ChoreCadence
    var weekDay: String?
}

struct ToggleChoreRequest: Codable, Sendable {
    var choreId: String
    var periodKey: String
}
