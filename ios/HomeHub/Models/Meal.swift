import Foundation

struct Meal: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var localDate: String
    var slot: MealSlot
    var title: String
    var recipeId: String?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct SaveMealRequest: Codable, Sendable {
    var localDate: String
    var slot: MealSlot
    var title: String
    var recipeId: String?
    var notes: String?
}

struct SnackCompletion: Codable, Sendable {
    let householdId: String
    let localDate: String
    let snackLabel: String
    var completedAt: Date
}

struct ToggleSnackRequest: Codable, Sendable {
    var localDate: String
    var snackLabel: String
}

struct SaveSnackOptionsRequest: Codable, Sendable {
    var snackOptions: String
}
