import Foundation
var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}
func p(_ s: String) -> String {
    let r = IngredientMerge.parse(s)
    return "q=\(r.quantity.map { String($0) } ?? "nil") u=\(r.unit ?? "nil") n=\(r.note ?? "nil") name=\(r.name) key=\(r.key)"
}
check("mixed number + unit", p("1 1/2 cups all-purpose flour"), "q=1.5 u=cup n=nil name=all-purpose flour key=all purpose flour")
check("count with size word", p("2 large eggs"), "q=2.0 u=nil n=nil name=large eggs key=egg")
check("can with size note", p("1 (14 oz) can diced tomatoes"), "q=1.0 u=can n=14 oz name=diced tomatoes key=diced tomato")
check("unicode fraction", p("½ tsp salt"), "q=0.5 u=tsp n=nil name=salt key=salt")
check("glued unicode fraction", p("1½ cups milk"), "q=1.5 u=cup n=nil name=milk key=milk")
check("range takes upper, prep note dropped", p("2-3 cloves garlic, minced"), "q=3.0 u=clove n=nil name=garlic key=garlic")
check("'to' range", p("1 to 2 cups rice"), "q=2.0 u=cup n=nil name=rice key=rice")
check("no quantity", p("Fresh basil"), "q=nil u=nil n=nil name=Fresh basil key=fresh basil")
check("abbrev with period", p("2 c. sugar"), "q=2.0 u=cup n=nil name=sugar key=sugar")
check("'tomatoes' is not a 'to' range", p("2 tomatoes"), "q=2.0 u=nil n=nil name=tomatoes key=tomato")
check("plural y", p("1 cup blueberries"), "q=1.0 u=cup n=nil name=blueberries key=blueberry")
check("unit-like word without quantity", p("cup noodles"), "q=nil u=nil n=nil name=cup noodles key=cup noodle")
check("optional paren in name dropped", p("1 tbsp honey (optional)"), "q=1.0 u=tbsp n=nil name=honey key=honey")

func m(_ entries: [(String, String)]) -> [String] {
    IngredientMerge.merge(entries.map { (source: $0.0, ingredient: $0.1) }).map { "\($0.displayText) <\($0.sources.joined(separator: ","))>" }
}
check("same unit adds", m([("Pancakes","1 cup flour"),("Bread","2 cups flour")]).joined(separator: "; "), "3 cups flour <Pancakes,Bread>")
check("singular/plural + size merge", m([("A","2 eggs"),("B","3 large eggs")]).joined(separator: "; "), "5 eggs <A,B>")
check("different units stay separate", m([("A","1 cup milk"),("B","2 tbsp milk")]).joined(separator: "; "), "1 cup milk <A>; 2 tbsp milk <B>")
check("bare mention dropped when amount exists", m([("A","salt"),("B","1 tsp salt")]).joined(separator: "; "), "1 tsp salt <B>")
check("bare alone kept", m([("A","salt")]).joined(separator: "; "), "salt <A>")
check("can sizes not merged", m([("A","1 (14 oz) can tomatoes"),("B","1 (28 oz) can tomatoes")]).joined(separator: "; "), "1 can (14 oz) tomatoes <A>; 1 can (28 oz) tomatoes <B>")
check("can plural display", m([("A","1 (14 oz) can beans"),("B","2 (14 oz) cans beans")]).joined(separator: "; "), "3 cans (14 oz) beans <A,B>")
check("weights add", m([("A","8 oz cream cheese"),("B","4 oz cream cheese")]).joined(separator: "; "), "12 oz cream cheese <A,B>")
check("same recipe twice lists source once", m([("Tacos","1 lb ground beef"),("Tacos","1 lb ground beef")]).joined(separator: "; "), "2 lb ground beef <Tacos>")
check("fractions sum", m([("A","1/2 cup sugar"),("B","1/4 cup sugar")]).joined(separator: "; "), "3/4 cup sugar <A,B>")

check("format 1/3", IngredientMerge.formatQuantity(1.0/3), "1/3")
check("format 2 1/2", IngredientMerge.formatQuantity(2.5), "2 1/2")
check("format whole", IngredientMerge.formatQuantity(3), "3")
check("format near-whole", IngredientMerge.formatQuantity(2.99), "3")
check("format odd decimal", IngredientMerge.formatQuantity(1.55), "1.55")
check("match existing title", IngredientMerge.matchKey(forTitle: "2 cups Flour"), "flour")
check("staple", String(IngredientMerge.isCommonStaple(key: IngredientMerge.matchKey(forTitle: "1 tsp kosher salt"))), "true")
check("non-staple", String(IngredientMerge.isCommonStaple(key: "flour")), "false")
print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
