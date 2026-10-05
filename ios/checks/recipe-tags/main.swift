import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}
func list(_ tags: [String]) -> String { tags.joined(separator: ", ") }

check("preset casing", RecipeTagHelpers.canonical("dINNer")!, "Dinner")
check("custom tag capitalized by word", RecipeTagHelpers.canonical("  slow   cooker ")!, "Slow Cooker")
check("hyphenated keeps its casing", RecipeTagHelpers.canonical("one-pot")!, "One-pot")
check("accents survive", RecipeTagHelpers.canonical("crème brûlée")!, "Crème Brûlée")
check("blank is nothing", String(describing: RecipeTagHelpers.canonical("   ")), "nil")
check("long tags are cut", String(RecipeTagHelpers.canonical(String(repeating: "a", count: 60))!.count), "24")

check("adding", list(RecipeTagHelpers.adding("beef", to: ["Dinner"])), "Dinner, Beef")
check("adding ignores duplicates", list(RecipeTagHelpers.adding("DINNER", to: ["Dinner"])), "Dinner")
check("adding ignores blanks", list(RecipeTagHelpers.adding(" ", to: ["Dinner"])), "Dinner")
let full = (1...12).map { "Tag \($0)" }
check("adding stops at the limit", String(RecipeTagHelpers.adding("one more", to: full).count), "12")
check("toggling on", list(RecipeTagHelpers.toggling("Pork", in: ["Dinner"])), "Dinner, Pork")
check("toggling off ignores case", list(RecipeTagHelpers.toggling("dinner", in: ["Dinner", "Pork"])), "Pork")

// A filter chip must switch off again whatever the tag looks like. Toggling for an editor re-spells the
// tag (cuts it to 24 characters, fixes spacing), which would leave a filter that no chip can remove.
let longTag = "Make Ahead Freezer Friendly Meals"
let oddSpacing = "Dinner  Party"
check("a filter for a long tag switches on", list(RecipeTagHelpers.togglingFilter(longTag, in: [])), longTag)
check("and off again", list(RecipeTagHelpers.togglingFilter(longTag, in: [longTag])), "")
check("odd spacing switches on and off", list(RecipeTagHelpers.togglingFilter(oddSpacing, in: RecipeTagHelpers.togglingFilter(oddSpacing, in: []))), "")
check("filter toggling ignores case when switching off", list(RecipeTagHelpers.togglingFilter("dinner", in: ["Dinner", "Pork"])), "Pork")
check("a filter keeps its order when another is added", list(RecipeTagHelpers.togglingFilter("Pork", in: ["Dinner"])), "Dinner, Pork")
check("filters are not capped at the editor's limit", String(RecipeTagHelpers.togglingFilter("one more", in: full).count), "13")
check("a recipe with the long tag matches the filter", String(RecipeTagHelpers.matches(recipeTags: [longTag], selected: RecipeTagHelpers.togglingFilter(longTag, in: []))), "true")

let used = RecipeTagHelpers.usedTags(in: [["Slow Cooker", "Chicken", "Dinner"], ["dinner", "Breakfast", "Beef"], ["Air Fryer"]])
check("used tags: meals, proteins, custom", list(used), "Breakfast, Dinner, Chicken, Beef, Air Fryer, Slow Cooker")
check("used tags with none", list(RecipeTagHelpers.usedTags(in: [[], []])), "")

check("match needs every selected tag", String(RecipeTagHelpers.matches(recipeTags: ["Dinner", "Chicken"], selected: ["dinner", "chicken"])), "true")
check("missing one tag fails", String(RecipeTagHelpers.matches(recipeTags: ["Dinner"], selected: ["Dinner", "Chicken"])), "false")
check("no filter matches everything", String(RecipeTagHelpers.matches(recipeTags: [], selected: [])), "true")

check("slot to meal tag", String(describing: RecipeTagHelpers.mealTag(forSlot: "dinner")), "Optional(\"Dinner\")")
check("unknown slot", String(describing: RecipeTagHelpers.mealTag(forSlot: "brunch")), "nil")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
