import Foundation

var failures = 0
func check(_ label: String, _ actual: Bool, _ expected: Bool) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got: \(actual) expected: \(expected)") }
}
let chili = "One-Pot Beef Chili"
let fajitas = "Sheet Pan Chicken Fajitas"

check("a word at the end", RecipeSearch.matches(title: chili, query: "chili"), true)
check("a word at the start", RecipeSearch.matches(title: chili, query: "one"), true)
check("a word in the middle", RecipeSearch.matches(title: fajitas, query: "chicken"), true)
check("a hyphenated word", RecipeSearch.matches(title: chili, query: "pot"), true)
check("the start of a word", RecipeSearch.matches(title: fajitas, query: "chick"), true)
check("case is ignored", RecipeSearch.matches(title: chili, query: "BEEF"), true)
check("accents are ignored", RecipeSearch.matches(title: "Café Mocha Cake", query: "cafe"), true)
check("accents typed match plain titles", RecipeSearch.matches(title: "Cafe Mocha Cake", query: "café"), true)
check("every word must be there", RecipeSearch.matches(title: fajitas, query: "pan fajita"), true)
check("in any order", RecipeSearch.matches(title: fajitas, query: "fajita sheet"), true)
check("a missing word fails", RecipeSearch.matches(title: fajitas, query: "pan salmon"), false)
check("no match", RecipeSearch.matches(title: chili, query: "salmon"), false)
check("an empty box matches everything", RecipeSearch.matches(title: chili, query: ""), true)
check("only spaces matches everything", RecipeSearch.matches(title: chili, query: "   "), true)
check("extra spaces and punctuation are ignored", RecipeSearch.matches(title: chili, query: "  beef,  chili! "), true)
check("words", RecipeSearch.words(in: " Beef  Chili ") == ["beef", "chili"], true)

if failures > 0 { print("\(failures) failed"); exit(1) } else { print("all passed") }
