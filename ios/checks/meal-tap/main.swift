import Foundation

var failures = 0
func check(_ label: String, _ actual: MealTapAction, _ expected: MealTapAction) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func meal(recipe: String? = nil, notes: String? = nil) -> Meal {
    Meal(localDate: "2026-11-15", slot: .dinner, title: "Dinner", recipeId: recipe, notes: notes)
}
func tap(_ meal: Meal?, editing: Bool = false, manage: Bool = true, recipes: Bool = true) -> MealTapAction {
    MealTapAction.resolve(meal: meal, isEditing: editing, canManage: manage, canOpenRecipes: recipes)
}

check("editing: a tap changes the meal", tap(meal(recipe: "r1"), editing: true), .edit)
check("editing: a tap on an empty slot adds one", tap(nil, editing: true), .edit)
check("not editing: a recipe opens", tap(meal(recipe: "r1")), .openRecipe("r1"))
check("not editing: an empty slot does nothing", tap(nil), .nothing)
check("not editing: a meal with nothing to show does nothing", tap(meal()), .nothing)
check("not editing: notes show when there is no recipe", tap(meal(notes: "Defrost the chicken")), .showNotes)
check("not editing: blank notes show nothing", tap(meal(notes: "  \n")), .nothing)
check("a recipe wins over notes", tap(meal(recipe: "r1", notes: "x")), .openRecipe("r1"))
check("recipes off: notes still show", tap(meal(recipe: "r1", notes: "x"), recipes: false), .showNotes)
check("recipes off: no notes means nothing", tap(meal(recipe: "r1"), recipes: false), .nothing)
check("a guest never edits, even if editing is somehow on", tap(meal(recipe: "r1"), editing: true, manage: false), .openRecipe("r1"))
check("a guest on an empty slot does nothing", tap(nil, editing: true, manage: false), .nothing)

if failures > 0 { print("\(failures) check(s) failed"); exit(1) }
print("all checks passed")
