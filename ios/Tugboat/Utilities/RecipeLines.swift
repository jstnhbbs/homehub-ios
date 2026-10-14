import Foundation

/// A line of a recipe's ingredients or directions, ready to show.
enum RecipeLine: Equatable, Sendable {
    case heading(String)
    /// `number` counts from 1 and starts over under each heading ("Crockpot", then "Stove").
    case item(number: Int, text: String)
}

/// Ingredient and direction lists are plain lists of text. A line starting with "## " is a heading
/// that groups what follows ("For the gravy"); the Crouton import writes them, and typing one in the
/// editor makes one. Everything that reads these lists has to treat headings as headings, or a
/// heading would turn up as a numbered step or a line on the grocery list.
enum RecipeLines {
    static let headingPrefix = "## "

    /// "1 ingredient", "18 ingredients" for a recipe card, counting items and not section headings.
    static func ingredientCountLabel(_ ingredients: [String]) -> String {
        let count = items(ingredients).count
        return count == 1 ? "1 ingredient" : "\(count) ingredients"
    }

    static func isHeading(_ line: String) -> Bool {
        line.hasPrefix(headingPrefix)
    }

    static func headingText(_ line: String) -> String {
        String(line.dropFirst(headingPrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The lines as they are shown: headings stand apart and numbering restarts under each one.
    static func display(_ lines: [String]) -> [RecipeLine] {
        var number = 0
        var result: [RecipeLine] = []
        for line in lines {
            if isHeading(line) {
                let text = headingText(line)
                guard !text.isEmpty else { continue }
                number = 0
                result.append(.heading(text))
            } else {
                number += 1
                result.append(.item(number: number, text: line))
            }
        }
        return result
    }

    /// Only the real ingredients: headings and blanks removed, whitespace trimmed.
    static func items(_ lines: [String]) -> [String] {
        lines
            .filter { !isHeading($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
