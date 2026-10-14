import Foundation

/// Recipe tags: short labels such as a meal type ("Dinner") or a protein ("Chicken").
/// These mirror the server's rules (src/lib/recipes/tags.ts) so the app shows what will be saved.
enum RecipeTagHelpers {
    static let mealTags = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]
    static let proteinTags = ["Chicken", "Beef", "Pork", "Turkey", "Fish", "Seafood", "Vegetarian"]
    static let presets = mealTags + proteinTags

    static let maxTags = 12
    static let maxTagLength = 24

    /// The preset's own spelling, or the text with each word capitalized.
    static func canonical(_ raw: String) -> String? {
        let cleaned = raw
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .prefix(maxTagLength)
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        if let preset = presets.first(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
            return preset
        }
        return cleaned
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func contains(_ tags: [String], _ tag: String) -> Bool {
        tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    /// Adds a tag if it is new and there is room; ignores blanks and duplicates.
    static func adding(_ raw: String, to tags: [String]) -> [String] {
        guard let tag = canonical(raw), !contains(tags, tag), tags.count < maxTags else { return tags }
        return tags + [tag]
    }

    static func toggling(_ tag: String, in tags: [String]) -> [String] {
        if contains(tags, tag) {
            return tags.filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
        }
        return adding(tag, to: tags)
    }

    /// Switches a filter chip on or off. The tag is used exactly as the chip shows it: `toggling`
    /// re-spells the tag the way the editor would (cut to 24 characters, spacing fixed, capped at 12),
    /// which for a tag that is not already in that form leaves a filter no chip can switch off.
    static func togglingFilter(_ tag: String, in filters: [String]) -> [String] {
        if contains(filters, tag) {
            return filters.filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
        }
        return filters + [tag]
    }

    /// Every tag in use, meal types first, then proteins, then custom tags alphabetically.
    static func usedTags(in tagLists: [[String]]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for tag in tagLists.flatMap({ $0 }) where seen.insert(tag.lowercased()).inserted {
            unique.append(tag)
        }
        func rank(_ tag: String) -> (Int, Int, String) {
            if let index = mealTags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                return (0, index, "")
            }
            if let index = proteinTags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                return (1, index, "")
            }
            return (2, 0, tag.lowercased())
        }
        return unique.sorted { rank($0) < rank($1) }
    }

    /// A recipe matches when it has every selected tag ("Dinner" + "Chicken" = chicken dinners).
    static func matches(recipeTags: [String], selected: [String]) -> Bool {
        selected.allSatisfy { contains(recipeTags, $0) }
    }

    /// The meal-type tag for a planner slot ("dinner" -> "Dinner"), if there is one.
    static func mealTag(forSlot slot: String) -> String? {
        mealTags.first { $0.caseInsensitiveCompare(slot) == .orderedSame }
    }
}
