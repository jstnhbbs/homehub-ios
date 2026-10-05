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

    private enum CodingKeys: String, CodingKey {
        case id
        case householdId
        case localDate
        case slot
        case title
        case recipeId
        case notes
        case createdAt
        case updatedAt
    }

    /// A meal created on the device before the server confirms it (optimistic updates).
    init(localDate: String, slot: MealSlot, title: String, recipeId: String? = nil, notes: String? = nil) {
        self.id = "\(localDate)-\(slot.rawValue)"
        self.householdId = ""
        self.localDate = localDate
        self.slot = slot
        self.title = title
        self.recipeId = recipeId
        self.notes = notes
        self.createdAt = nil
        self.updatedAt = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localDate = try container.decode(String.self, forKey: .localDate)
        slot = try container.decode(MealSlot.self, forKey: .slot)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(localDate)-\(slot.rawValue)"
        householdId = try container.decodeIfPresent(String.self, forKey: .householdId) ?? ""
        title = try container.decode(String.self, forKey: .title)
        recipeId = try container.decodeIfPresent(String.self, forKey: .recipeId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
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
    /// The child who ate it. Only sent when the household tracks snacks per child.
    var profileId: String?
    /// The state wanted, so a repeated request can't flip it back. Servers that predate this
    /// ignore it and flip the snack.
    var completed: Bool?
}

/// Either field may be sent alone; the server leaves whatever is omitted as it was.
struct SaveSnackOptionsRequest: Codable, Sendable {
    var snackOptions: String?
    var snacksPerChild: Bool?
}

/// One snack eaten today. `profileId` is nil for the household-wide checklist.
struct SnackEatenRecord: Codable, Hashable, Sendable {
    let snackLabel: String
    var profileId: String?
}
