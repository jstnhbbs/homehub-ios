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

    private enum CodingKeys: String, CodingKey {
        case id
        case householdId
        case title
        case description
        case servings
        case prepTime
        case cookTime
        case totalTime
        case ingredients
        case directions
        case nutrition
        case sourceUrl
        case imageUrl
        case notes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        householdId = try container.decodeIfPresent(String.self, forKey: .householdId) ?? ""
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        servings = try container.decodeIfPresent(String.self, forKey: .servings)
        prepTime = try container.decodeIfPresent(String.self, forKey: .prepTime)
        cookTime = try container.decodeIfPresent(String.self, forKey: .cookTime)
        totalTime = try container.decodeIfPresent(String.self, forKey: .totalTime)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        directions = try container.decodeIfPresent([String].self, forKey: .directions) ?? []
        nutrition = try container.decodeIfPresent([String: String].self, forKey: .nutrition)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
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
