import Foundation

/// Splits an ingredient line into its amount ("1 1/2 Tbsp", "8 oz", "3") and the rest ("olive oil"), so the
/// amount can be shown in the accent color. A line with no leading number has no amount ("half an onion").
enum RecipeIngredientParts {
    private static let units: Set<String> = [
        "tsp", "tsps", "teaspoon", "teaspoons", "tbsp", "tbsps", "tablespoon", "tablespoons",
        "cup", "cups", "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds",
        "g", "gram", "grams", "kg", "kilogram", "kilograms", "ml", "milliliter", "milliliters",
        "l", "liter", "liters", "litre", "litres", "qt", "quart", "quarts", "pt", "pint", "pints",
        "gal", "gallon", "gallons",
    ]

    private static let fractionCharacters = CharacterSet(charactersIn: "¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞")

    static func split(_ line: String) -> (amount: String, rest: String) {
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var count = 0
        while count < tokens.count, isNumber(tokens[count]) { count += 1 }
        guard count > 0 else { return ("", line) }
        if count < tokens.count, isUnit(tokens[count]) { count += 1 }
        let amount = tokens[0..<count].joined(separator: " ")
        let rest = tokens[count...].joined(separator: " ")
        return (amount, rest)
    }

    private static func isNumber(_ token: String) -> Bool {
        guard let first = token.unicodeScalars.first else { return false }
        let isDigit = CharacterSet.decimalDigits.contains(first)
        guard isDigit || fractionCharacters.contains(first) else { return false }
        // Digits, fractions and the separators of "1/2", "1.5", "2-3", "2–3".
        let allowed = CharacterSet.decimalDigits.union(fractionCharacters).union(CharacterSet(charactersIn: "/.-–"))
        return token.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isUnit(_ token: String) -> Bool {
        units.contains(token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }
}
