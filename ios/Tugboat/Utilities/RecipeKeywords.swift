import Foundation

/// Finds the ingredients a method step mentions so the recipe page can color them ("Add the onion, garlic and
/// beef"). Each ingredient contributes its name as written ("taco seasoning") and its last word ("beef" from
/// "ground beef"); a word matches with or without a plural ending.
enum RecipeKeywords {
    private static let ignoredWords: Set<String> = [
        "taste", "needed", "garnish", "optional", "size", "divided", "more", "extra", "serving", "topping",
        "toppings", "fresh", "water", "pieces", "piece", "other", "each", "plus", "about",
    ]

    /// The words and phrases to look for, longest first, for the recipe's ingredient lines.
    static func keywords(for ingredients: [String]) -> [String] {
        var found: Set<String> = []
        for line in RecipeLines.items(ingredients) {
            var name = RecipeIngredientParts.split(line).rest
            if let paren = name.firstIndex(of: "(") { name = String(name[..<paren]) }
            if let comma = name.firstIndex(of: ",") { name = String(name[..<comma]) }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let words = name.split(separator: " ").map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            guard let last = words.last else { continue }
            if words.count > 1 { found.insert(singular(words.joined(separator: " "))) }
            if last.count >= 3, !ignoredWords.contains(last) { found.insert(singular(last)) }
        }
        return found.sorted { ($0.count, $0) > ($1.count, $1) }
    }

    /// Where the keywords appear in `text`, whole words only, without overlaps.
    static func ranges(of keywords: [String], in text: String) -> [Range<String.Index>] {
        guard !keywords.isEmpty else { return [] }
        let alternation = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "\\b(?:\(alternation))(?:e?s)?\\b", options: [.caseInsensitive])
        else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: whole).compactMap { Range($0.range, in: text) }
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes"), word.count > 4 { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }
}
