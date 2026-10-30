import Foundation

var failures = 0
func check(_ line: String, _ amount: String, _ rest: String) {
    let got = RecipeIngredientParts.split(line)
    if got.amount == amount && got.rest == rest { print("ok   \(line)") } else {
        failures += 1; print("FAIL \(line)\n     got: [\(got.amount)] [\(got.rest)] expected: [\(amount)] [\(rest)]")
    }
}
check("1 Tbsp olive oil", "1 Tbsp", "olive oil")
check("half an onion, minced", "", "half an onion, minced")
check("3 cloves garlic, minced", "3", "cloves garlic, minced")
check("1 lb ground beef", "1 lb", "ground beef")
check("1 1/2 cups flour", "1 1/2 cups", "flour")
check("½ tsp salt", "½ tsp", "salt")
check("1½ cups milk", "1½ cups", "milk")
check("2-3 Tbsp butter", "2-3 Tbsp", "butter")
check("8 oz shredded Pepperjack cheese", "8 oz", "shredded Pepperjack cheese")
check("2 large eggs", "2", "large eggs")
check("1 cup", "1 cup", "")
check("Salt to taste", "", "Salt to taste")
check("1.5 L water", "1.5 L", "water")
check("", "", "")
if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
