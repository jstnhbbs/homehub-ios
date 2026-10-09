import Foundation

/// One recipe from a Crouton export. A `.crumb` file is JSON; only the text fields are kept here
/// and they are sent as they are, because the server decides how each one becomes a Porchlight recipe
/// (see `src/lib/recipes/crouton.ts`). The photos travel separately, resized.
struct CroutonRecipePayload: Codable, Sendable, Equatable {
    var uuid: String
    var name: String
    var webLink: String?
    var sourceName: String?
    var serves: Double?
    var duration: Double?
    var cookingDuration: Double?
    var neutritionalInfo: String?
    var notes: String?
    var ingredients: [Ingredient]
    var steps: [Step]
    var tags: [Tag]?

    struct Ingredient: Codable, Sendable, Equatable {
        var order: Double?
        var ingredient: Named
        var quantity: Quantity?
    }

    struct Named: Codable, Sendable, Equatable {
        var name: String
    }

    struct Quantity: Codable, Sendable, Equatable {
        var quantityType: String?
        var amount: Double?
        var secondaryAmount: Double?
    }

    struct Step: Codable, Sendable, Equatable {
        var order: Double?
        var step: String
        var isSection: Bool?
    }

    struct Tag: Codable, Sendable, Equatable {
        var name: String
    }
}

/// A `.crumb` file as read from disk: the recipe, plus its main photo as the base64 text Crouton stores.
struct CroutonRecipeFile: Decodable, Sendable {
    let recipe: CroutonRecipePayload
    /// The full-size photo. The thumbnail Crouton also stores (`sourceImage`) is deliberately ignored:
    /// it is a couple of kilobytes and looks it.
    let photoBase64: String?

    private enum CodingKeys: String, CodingKey {
        case images
    }

    init(from decoder: Decoder) throws {
        recipe = try CroutonRecipePayload(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photoBase64 = try container.decodeIfPresent([String].self, forKey: .images)?.first
    }
}

struct CroutonImportRequest: Encodable, Sendable {
    var recipes: [CroutonRecipePayload]
}

struct CroutonImportResponse: Decodable, Sendable {
    let results: [CroutonImportResult]
    let created: Int
    let duplicates: Int
    let failed: Int
}

struct CroutonImportResult: Decodable, Sendable {
    enum Status: String, Decodable, Sendable {
        case created
        case duplicate
        case failed
    }

    let index: Int
    let title: String
    let status: Status
    let id: String?
    let error: String?
    /// For a duplicate: whether Porchlight already has its photo. Nil from a server that doesn't say.
    let hasPhoto: Bool?
}
