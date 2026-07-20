import Foundation

struct Recipe: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var title: String
    var description: String?
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var ingredients: [String]
    var directions: [String]
    var nutrition: [String: String]?
    var sourceUrl: String?
    var imageUrl: String?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct RecipeInput: Codable, Sendable {
    var title: String
    var description: String?
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var ingredients: [String]
    var directions: [String]
    var nutrition: [String: String]?
    var sourceUrl: String?
    var imageUrl: String?
    var notes: String?
}

struct ImportRecipeRequest: Codable, Sendable {
    var url: String
}
