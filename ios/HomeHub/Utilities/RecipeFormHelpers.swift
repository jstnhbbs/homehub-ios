import Foundation

struct RecipeOption: Identifiable, Sendable {
    let id: String
    let title: String
}

extension Recipe {
    var asOption: RecipeOption {
        RecipeOption(id: id, title: title)
    }

    func toInput() -> RecipeInput {
        RecipeInput(
            title: title,
            description: description,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: totalTime,
            ingredients: ingredients,
            directions: directions,
            nutrition: nutrition,
            sourceUrl: sourceUrl,
            imageUrl: imageUrl,
            notes: notes
        )
    }
}

enum RecipeFormHelpers {
    static func ingredientsText(_ items: [String]) -> String {
        items.joined(separator: "\n")
    }

    static func directionsText(_ items: [String]) -> String {
        items.joined(separator: "\n")
    }

    static func nutritionText(_ nutrition: [String: String]?) -> String {
        guard let nutrition else { return "" }
        return nutrition.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    static func parseLines(_ text: String) -> [String] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func parseNutrition(_ text: String) -> [String: String]? {
        let lines = parseLines(text)
        guard !lines.isEmpty else { return nil }
        var nutrition: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { continue }
            nutrition[parts[0]] = parts[1]
        }
        return nutrition.isEmpty ? nil : nutrition
    }

    static func buildInput(
        title: String,
        description: String,
        servings: String,
        prepTime: String,
        cookTime: String,
        totalTime: String,
        ingredientsText: String,
        directionsText: String,
        nutritionText: String,
        sourceUrl: String,
        imageUrl: String,
        notes: String
    ) -> RecipeInput? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredients = parseLines(ingredientsText)
        let directions = parseLines(directionsText)
        guard !trimmedTitle.isEmpty, !ingredients.isEmpty, !directions.isEmpty else { return nil }

        return RecipeInput(
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            servings: servings.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            prepTime: prepTime.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            cookTime: cookTime.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            totalTime: totalTime.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            ingredients: ingredients,
            directions: directions,
            nutrition: parseNutrition(nutritionText),
            sourceUrl: sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            imageUrl: imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
