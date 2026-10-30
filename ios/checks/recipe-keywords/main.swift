import Foundation

var failures = 0
func check(_ label: String, _ actual: [String], _ expected: [String]) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got: \(actual)\n     expected: \(expected)") }
}
func found(_ step: String, _ ingredients: [String]) -> [String] {
    let k = RecipeKeywords.keywords(for: ingredients)
    return RecipeKeywords.ranges(of: k, in: step).map { String(step[$0]) }
}
let taco = [
    "1 Tbsp olive oil", "half an onion, minced", "3 cloves garlic, minced", "1 lb ground beef",
    "2 Tbsp taco seasoning (add about 1 teaspoon salt if it's unsalted)", "4 Tbsp butter", "4 Tbsp flour", "1 cup milk",
    "8 oz shredded Pepperjack cheese", "large flour tortillas (burrito size)", "sour cream", "salsa",
    "## For the gravy", "Salt to taste",
]
check("oil, onion, garlic, beef", found("Heat the oil over medium heat. Add onion, garlic, and beef.", taco), ["oil", "onion", "garlic", "beef"])
check("phrase", found("Add taco seasoning and salt.", taco), ["taco seasoning"])
check("two-word phrase", found("Top with sour cream and salsa.", taco), ["sour cream", "salsa"])
check("plural tortillas", found("Lay a large tortilla flat; fold the tortillas.", taco), ["tortilla", "tortillas"])
check("whole words only", found("Cook the boiling beefy broth.", taco), [])
check("taste is not a keyword", found("Season to taste.", taco), [])
check("heading ignored", found("Make the gravy.", taco), [])
check("no ingredients", found("Add onion.", []), [])
if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
