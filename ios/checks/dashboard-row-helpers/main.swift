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

// Rows that fit a measured height
check("fills a tall single column", String(DashboardRowHelpers.visibleRowCount(availableHeight: 500, rowHeight: 40, spacing: 8, columns: 1, total: 100)), "10")
check("never shows more than exist", String(DashboardRowHelpers.visibleRowCount(availableHeight: 5000, rowHeight: 40, spacing: 8, columns: 1, total: 3)), "3")
check("always at least one row, even if it slightly overflows", String(DashboardRowHelpers.visibleRowCount(availableHeight: 10, rowHeight: 40, spacing: 8, columns: 1, total: 5)), "1")
check("two columns doubles what one row holds", String(DashboardRowHelpers.visibleRowCount(availableHeight: 48, rowHeight: 40, spacing: 8, columns: 2, total: 100)), "2")
check("zero height still shows one row's worth, not an empty-state flash", String(DashboardRowHelpers.visibleRowCount(availableHeight: 0, rowHeight: 40, spacing: 8, columns: 1, total: 5)), "1")
check("zero height, two columns shows one row of two", String(DashboardRowHelpers.visibleRowCount(availableHeight: 0, rowHeight: 40, spacing: 8, columns: 2, total: 5)), "2")
check("negative height (still unmeasured) behaves the same as zero", String(DashboardRowHelpers.visibleRowCount(availableHeight: -20, rowHeight: 40, spacing: 8, columns: 1, total: 5)), "1")
check("nothing to show", String(DashboardRowHelpers.visibleRowCount(availableHeight: 500, rowHeight: 40, spacing: 8, columns: 1, total: 0)), "0")
check(
    "a taller card shows more than a shorter one",
    String(
        DashboardRowHelpers.visibleRowCount(availableHeight: 400, rowHeight: 40, spacing: 8, columns: 1, total: 100)
            > DashboardRowHelpers.visibleRowCount(availableHeight: 150, rowHeight: 40, spacing: 8, columns: 1, total: 100)
    ),
    "true"
)

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
