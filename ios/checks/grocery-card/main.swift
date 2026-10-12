import Foundation
import CoreGraphics

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func item(_ title: String, _ category: String = "Other", checked: Bool = false) -> GroceryItem {
    GroceryItem(id: title, householdId: "h", title: title, quantity: nil, category: category, checked: checked, checkedAt: nil, sortOrder: 0, createdAt: nil, updatedAt: nil)
}
func names(_ entries: [GroceryEntry]) -> String {
    entries.map { entry -> String in
        switch entry {
        case .header(let name): "[\(name)]"
        case .item(let item): item.title
        }
    }.joined(separator: " ")
}

// MARK: wording

let some = GroceryCardSummary(items: [item("milk", "Dairy"), item("eggs", "Dairy"), item("apples", "Produce")], checked: [], isServerBacked: true)
check("headline is the count", some.headline, "3")
check("caption", some.caption, "items to buy")
check("line", some.line, "3 to buy")
check("one item", GroceryCardSummary(items: [item("milk")], checked: [], isServerBacked: true).caption, "item to buy")
let none = GroceryCardSummary(items: [], checked: [], isServerBacked: true)
check("nothing to buy", none.headline, "All set")
check("nothing to buy line", none.line, "Nothing to buy")

// MARK: grouping

check("grouped by aisle when there are several", names(some.entries), "[Dairy] milk eggs [Produce] apples")
let oneAisle = GroceryCardSummary(items: [item("milk", "Dairy"), item("eggs", "Dairy")], checked: [], isServerBacked: true)
check("one aisle needs no heading", names(oneAisle.entries), "milk eggs")
let reminders = GroceryCardSummary(items: [item("milk", "Groceries"), item("eggs", "Groceries")], checked: [], isServerBacked: false)
check("a Reminders list is plain", names(reminders.entries), "milk eggs")
let withChecked = GroceryCardSummary(items: [item("milk", "Dairy"), item("apples", "Produce")], checked: [item("bread", "Bakery", checked: true)], isServerBacked: true)
check("checked-off items come last under their own heading", names(withChecked.entries), "[Dairy] milk [Produce] apples [Checked off] bread")

// MARK: fitting into columns

func fit(_ entries: [GroceryEntry], columns: Int = 2, height: CGFloat) -> GroceryCardSummary.Layout {
    GroceryCardSummary.fit(entries, columnCount: columns, itemHeight: 50, headerHeight: 20, spacing: 10, footerHeight: 20, availableHeight: height)
}
func shape(_ layout: GroceryCardSummary.Layout) -> String { layout.columns.map { names($0) }.joined(separator: " | ") + " /\(layout.hiddenItems)" }

let few = Array(some.entries)
check("all of it fits", shape(fit(few, height: 400)), "[Dairy] milk eggs [Produce] apples |  /0")
check("it flows into the second column", shape(fit(few, height: 140)), "[Dairy] milk eggs | [Produce] apples /0")
check("a heading goes with its first item, never alone", shape(fit(few, height: 110)), "[Dairy] milk | eggs /1")
let long = (1...10).map { GroceryEntry.item(item("i\($0)")) }
check("what does not fit is counted", shape(fit(long, columns: 2, height: 130)), "i1 i2 | i3 i4 /6")
check("one column", shape(fit(long, columns: 1, height: 130)), "i1 i2 /8")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
