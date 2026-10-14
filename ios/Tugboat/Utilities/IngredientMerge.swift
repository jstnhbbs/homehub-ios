import Foundation

/// One ingredient line ("1 1/2 cups all-purpose flour") split into parts.
struct ParsedIngredient: Equatable, Sendable {
    var quantity: Double?
    var unit: String?
    /// Parenthetical size after the quantity, e.g. "14 oz" in "1 (14 oz) can diced tomatoes".
    var note: String?
    var name: String
    /// Lowercased, singularized name used to match the same ingredient across recipes.
    var key: String
}

/// An ingredient combined across every recipe that uses it.
struct MergedIngredient: Equatable, Identifiable, Sendable {
    var id: String
    var quantity: Double?
    var unit: String?
    var note: String?
    var name: String
    var key: String
    var sources: [String]

    var displayText: String {
        IngredientMerge.displayText(quantity: quantity, unit: unit, note: note, name: name)
    }
}

/// Combines free-text recipe ingredients into a shopping list.
///
/// Amounts are only added together when the ingredient and unit match ("1 cup flour" +
/// "2 cups flour"). Different units are kept as separate lines rather than guessing at
/// conversions, so the list stays honest and the user can adjust it before adding.
enum IngredientMerge {
    static func parse(_ raw: String) -> ParsedIngredient {
        var text = normalizeFractions(raw)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        var quantity: Double?
        if let match = firstMatch(quantityPattern, in: text) {
            let numbers = match.captures.compactMap(parseNumber)
            quantity = numbers.max()
            text = String(text[match.range.upperBound...])
        }

        var note: String?
        if let match = firstMatch(#"^\(([^)]*)\)\s*"#, in: text) {
            note = match.captures.first?.trimmingCharacters(in: .whitespaces)
            text = String(text[match.range.upperBound...])
        }

        var unit: String?
        let words = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if quantity != nil,
           words.count == 2,
           let canonical = canonicalUnit(String(words[0])) {
            unit = canonical
            text = String(words[1])
        }

        let name = cleanName(text)
        return ParsedIngredient(
            quantity: quantity,
            unit: unit,
            note: note?.isEmpty == true ? nil : note,
            name: name,
            key: matchKey(name)
        )
    }

    /// Merges `(source, ingredient)` pairs. `source` is the recipe title shown in the preview.
    static func merge(_ entries: [(source: String, ingredient: String)]) -> [MergedIngredient] {
        var order: [String] = []
        var groups: [String: MergedIngredient] = [:]

        for entry in entries {
            let parsed = parse(entry.ingredient)
            guard !parsed.key.isEmpty else { continue }
            let groupId = [parsed.key, parsed.unit ?? "", (parsed.note ?? "").lowercased()]
                .joined(separator: "|")

            if var existing = groups[groupId] {
                if let quantity = parsed.quantity {
                    existing.quantity = (existing.quantity ?? 0) + quantity
                }
                if !existing.sources.contains(entry.source) {
                    existing.sources.append(entry.source)
                }
                groups[groupId] = existing
            } else {
                order.append(groupId)
                groups[groupId] = MergedIngredient(
                    id: groupId,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    note: parsed.note,
                    name: parsed.name,
                    key: parsed.key,
                    sources: [entry.source]
                )
            }
        }

        // A bare mention ("salt") adds nothing once the same ingredient has an amount ("1 tsp salt").
        let keysWithAmounts = Set(
            groups.values
                .filter { $0.quantity != nil || $0.unit != nil }
                .map(\.key)
        )
        return order.compactMap { groupId in
            guard let item = groups[groupId] else { return nil }
            let isBare = item.quantity == nil && item.unit == nil
            if isBare, keysWithAmounts.contains(item.key) { return nil }
            return item
        }
    }

    static func displayText(quantity: Double?, unit: String?, note: String?, name: String) -> String {
        var parts: [String] = []
        if let quantity {
            parts.append(formatQuantity(quantity))
        }
        if let unit {
            parts.append(displayUnit(unit, quantity: quantity))
        }
        if let note {
            parts.append("(\(note))")
        }
        parts.append(name)
        return parts.joined(separator: " ")
    }

    /// Key for matching an existing list item ("2 cups flour" or "flour") against a merged ingredient.
    static func matchKey(forTitle title: String) -> String {
        parse(title).key
    }

    /// Things most kitchens already have. The preview leaves these unchecked by default.
    static func isCommonStaple(key: String) -> Bool {
        stapleKeys.contains(key)
    }

    // MARK: - Parsing helpers

    private static let number = #"(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"#
    private static let quantityPattern = "^" + number + #"(?:\s*(?:-|–|—|to)\s*"# + number + #")?(?![\d/])\s*"#

    private static let stapleKeys: Set<String> = [
        "salt", "kosher salt", "sea salt", "pepper", "black pepper", "ground black pepper",
        "water", "ice", "cooking spray",
    ]

    private static let unitTable: [String: String] = {
        let groups: [String: [String]] = [
            "cup": ["cup", "cups", "c"],
            "tbsp": ["tbsp", "tbsps", "tablespoon", "tablespoons", "tbs", "tb"],
            "tsp": ["tsp", "tsps", "teaspoon", "teaspoons"],
            "oz": ["oz", "ounce", "ounces"],
            "lb": ["lb", "lbs", "pound", "pounds"],
            "g": ["g", "gram", "grams"],
            "kg": ["kg", "kilogram", "kilograms"],
            "ml": ["ml", "milliliter", "milliliters"],
            "l": ["l", "liter", "liters", "litre", "litres"],
            "pt": ["pt", "pint", "pints"],
            "qt": ["qt", "quart", "quarts"],
            "gal": ["gal", "gallon", "gallons"],
            "clove": ["clove", "cloves"],
            "can": ["can", "cans"],
            "package": ["package", "packages", "pkg", "pkgs", "pack", "packs", "packet", "packets"],
            "stick": ["stick", "sticks"],
            "slice": ["slice", "slices"],
            "bunch": ["bunch", "bunches"],
            "pinch": ["pinch", "pinches"],
            "dash": ["dash", "dashes"],
        ]
        var table: [String: String] = [:]
        for (canonical, spellings) in groups {
            for spelling in spellings {
                table[spelling] = canonical
            }
        }
        return table
    }()

    private static let wordUnits: Set<String> = [
        "cup", "clove", "can", "package", "stick", "slice", "bunch", "pinch", "dash",
    ]

    private static func canonicalUnit(_ word: String) -> String? {
        let cleaned = word.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        return unitTable[cleaned]
    }

    private static func displayUnit(_ unit: String, quantity: Double?) -> String {
        guard wordUnits.contains(unit), (quantity ?? 1) > 1 else { return unit }
        if unit == "bunch" || unit == "pinch" || unit == "dash" { return unit + "es" }
        return unit + "s"
    }

    private static func cleanName(_ raw: String) -> String {
        var name = raw
        if let comma = name.firstIndex(of: ",") {
            name = String(name[..<comma])
        }
        name = name.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"^(of|a|an)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchKey(_ name: String) -> String {
        let lowered = name.lowercased()
            .replacingOccurrences(of: #"[^a-z\s]"#, with: " ", options: .regularExpression)
        var words = lowered.split(separator: " ").map(String.init)
        words.removeAll { ["large", "medium", "small"].contains($0) }
        guard let last = words.last else { return "" }
        words[words.count - 1] = singular(last)
        return words.joined(separator: " ")
    }

    private static func singular(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 4, word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") {
            return String(word.dropLast())
        }
        return word
    }

    private static func normalizeFractions(_ text: String) -> String {
        let fractions: [Character: String] = [
            "½": " 1/2", "¼": " 1/4", "¾": " 3/4", "⅓": " 1/3", "⅔": " 2/3",
            "⅛": " 1/8", "⅜": " 3/8", "⅝": " 5/8", "⅞": " 7/8",
        ]
        var result = ""
        for character in text {
            result += fractions[character] ?? String(character)
        }
        return result
    }

    private static func parseNumber(_ text: String) -> Double? {
        let parts = text.split(separator: " ").map(String.init)
        var total = 0.0
        for part in parts {
            if part.contains("/") {
                let pieces = part.split(separator: "/")
                guard pieces.count == 2,
                      let top = Double(pieces[0]),
                      let bottom = Double(pieces[1]),
                      bottom != 0 else { return nil }
                total += top / bottom
            } else if let value = Double(part) {
                total += value
            } else {
                return nil
            }
        }
        return total
    }

    private struct RegexMatch {
        var range: Range<String.Index>
        var captures: [String]
    }

    private static func firstMatch(_ pattern: String, in text: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            if let captureRange = Range(match.range(at: index), in: text) {
                captures.append(String(text[captureRange]))
            }
        }
        return RegexMatch(range: range, captures: captures)
    }

    // MARK: - Formatting

    private static let fractionSteps: [(value: Double, text: String)] = [
        (1.0 / 8, "1/8"), (1.0 / 4, "1/4"), (1.0 / 3, "1/3"), (3.0 / 8, "3/8"),
        (1.0 / 2, "1/2"), (5.0 / 8, "5/8"), (2.0 / 3, "2/3"), (3.0 / 4, "3/4"), (7.0 / 8, "7/8"),
    ]

    static func formatQuantity(_ quantity: Double) -> String {
        var whole = Int(quantity.rounded(.down))
        let fraction = quantity - Double(whole)
        if fraction < 0.04 {
            return String(whole)
        }
        if fraction > 0.96 {
            whole += 1
            return String(whole)
        }
        if let step = fractionSteps.min(by: { abs($0.value - fraction) < abs($1.value - fraction) }),
           abs(step.value - fraction) < 0.04 {
            return whole == 0 ? step.text : "\(whole) \(step.text)"
        }
        let rounded = (quantity * 100).rounded() / 100
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
    }
}
