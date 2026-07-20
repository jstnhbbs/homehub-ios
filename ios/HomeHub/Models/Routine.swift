import Foundation

struct Routine: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var profileId: String?
    var name: String
    var period: RoutinePeriod
    var days: String
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?
    var steps: [RoutineStep]?
}

struct RoutineStep: Codable, Identifiable, Sendable {
    let id: String
    let routineId: String
    var label: String
    var sortOrder: Int
}

struct RoutineCompletion: Codable, Sendable {
    let stepId: String
    let localDate: String
    var completedAt: Date
}

struct RoutineStepRow: Codable, Identifiable, Sendable {
    let id: String
    var label: String
    var routineName: String
    var period: RoutinePeriod
    var profileId: String?
    var completed: Bool
}

struct RoutineInput: Codable, Sendable {
    var name: String
    var period: RoutinePeriod
    var profileId: String?
    var days: String
    var steps: [String]
}

struct ToggleRoutineStepRequest: Codable, Sendable {
    var stepId: String
    var localDate: String
}
