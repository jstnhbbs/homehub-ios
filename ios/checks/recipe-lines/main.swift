import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func describe(_ lines: [RecipeLine]) -> String {
    lines.map { line in
        switch line {
        case .heading(let text): "# \(text)"
        case .item(let number, let text): "\(number). \(text)"
        }
    }.joined(separator: " | ")
}

check("a plain list is numbered from one", describe(RecipeLines.display(["Mix", "Bake", "Cool"])), "1. Mix | 2. Bake | 3. Cool")
check("headings stand apart and numbering restarts under each",
      describe(RecipeLines.display(["## Crockpot", "Combine", "Cook", "## Stove", "Simmer"])),
      "# Crockpot | 1. Combine | 2. Cook | # Stove | 1. Simmer")
check("steps before the first heading are numbered too",
      describe(RecipeLines.display(["Prep", "## Sauce", "Whisk"])),
      "1. Prep | # Sauce | 1. Whisk")
check("an empty heading is dropped", describe(RecipeLines.display(["## ", "Mix"])), "1. Mix")
check("text that only contains ## is not a heading", describe(RecipeLines.display(["Mix ## well"])), "1. Mix ## well")
check("a heading needs the space after ##", describe(RecipeLines.display(["##Mix"])), "1. ##Mix")
check("nothing", describe(RecipeLines.display([])), "")

check("heading text is trimmed", RecipeLines.headingText("##   Gravy  "), "Gravy")
check("heading text", RecipeLines.headingText("## Gravy"), "Gravy")
check("is a heading", String(RecipeLines.isHeading("## Gravy")), "true")
check("is not a heading", String(RecipeLines.isHeading("1 cup flour")), "false")

check("the grocery list gets real ingredients only",
      RecipeLines.items(["## Gravy", "2 cups broth", "   ", "  1 tbsp flour  ", "## Mash", "3 potatoes"]).joined(separator: " | "),
      "2 cups broth | 1 tbsp flour | 3 potatoes")
check("and a list of only headings gives nothing", String(RecipeLines.items(["## A", "## B"]).count), "0")

check("one ingredient is singular", RecipeLines.ingredientCountLabel(["1 thing"]), "1 ingredient")
check("several ingredients are plural", RecipeLines.ingredientCountLabel(["flour", "sugar", "eggs"]), "3 ingredients")
check("none is plural", RecipeLines.ingredientCountLabel([]), "0 ingredients")
check("section headings are not counted", RecipeLines.ingredientCountLabel(["## Sauce", "salt"]), "1 ingredient")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
