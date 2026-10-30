import Foundation

/// The recipe search box. A recipe matches when every word typed appears somewhere in its title, in any order and
/// whatever its case or accents, so "chili" finds "One-Pot Beef Chili", "pan fajita" finds "Sheet Pan Chicken
/// Fajitas" and "cafe" finds "Café Mocha Cake". Foundation only, checked in `ios/checks/recipe-search`.
enum RecipeSearch {
    /// The words typed, folded for comparison. Empty when the box is empty or only spaces.
    static func words(in query: String) -> [String] {
        fold(query).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static func matches(title: String, words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let folded = fold(title)
        return words.allSatisfy { folded.contains($0) }
    }

    static func matches(title: String, query: String) -> Bool {
        matches(title: title, words: words(in: query))
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
