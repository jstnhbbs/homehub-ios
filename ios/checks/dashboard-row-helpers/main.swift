import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// Grocery subtitle
check("native reminder, no quantity: nothing to show", String(describing: DashboardRowHelpers.grocerySubtitle(quantity: nil, category: "Chores", isServerBacked: false)), "nil")
check("native reminder with blank quantity: still nothing", String(describing: DashboardRowHelpers.grocerySubtitle(quantity: "  ", category: "Chores", isServerBacked: false)), "nil")
check("native reminder with a real quantity: shows it", String(describing: DashboardRowHelpers.grocerySubtitle(quantity: "2 gal", category: "Chores", isServerBacked: false)), "Optional(\"2 gal\")")
check("server item with no quantity: shows its real category", String(describing: DashboardRowHelpers.grocerySubtitle(quantity: nil, category: "Produce", isServerBacked: true)), "Optional(\"Produce\")")
check("server item with a quantity: quantity wins", String(describing: DashboardRowHelpers.grocerySubtitle(quantity: "3", category: "Produce", isServerBacked: true)), "Optional(\"3\")")

// Calendar name
check("one calendar: not worth repeating", String(DashboardRowHelpers.showsCalendarName(["Family", "Family", "Family"])), "false")
check("two calendars: worth showing", String(DashboardRowHelpers.showsCalendarName(["Family", "Work"])), "true")
check("some events with no calendar name at all", String(DashboardRowHelpers.showsCalendarName(["Family", nil, "Family"])), "false")
check("no events", String(DashboardRowHelpers.showsCalendarName([])), "false")
check("all nil", String(DashboardRowHelpers.showsCalendarName([nil, nil])), "false")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
