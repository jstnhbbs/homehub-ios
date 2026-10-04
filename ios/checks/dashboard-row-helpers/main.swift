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

// How many columns fit a measured width
check("a narrow card gets one column", String(DashboardRowHelpers.columnCount(availableWidth: 276, minimumColumnWidth: 165, spacing: 8)), "1")
check("a wide card gets two", String(DashboardRowHelpers.columnCount(availableWidth: 400, minimumColumnWidth: 165, spacing: 8)), "2")
check("exactly two minimums plus the gap still fits two", String(DashboardRowHelpers.columnCount(availableWidth: 338, minimumColumnWidth: 165, spacing: 8)), "2")
check("one point short of that drops to one", String(DashboardRowHelpers.columnCount(availableWidth: 337, minimumColumnWidth: 165, spacing: 8)), "1")
check("never exceeds the cap however wide", String(DashboardRowHelpers.columnCount(availableWidth: 2000, minimumColumnWidth: 165, spacing: 8)), "2")
check("a higher cap allows more", String(DashboardRowHelpers.columnCount(availableWidth: 2000, minimumColumnWidth: 165, spacing: 8, maxColumns: 4)), "4")
check("unmeasured width falls back to one column", String(DashboardRowHelpers.columnCount(availableWidth: 0, minimumColumnWidth: 165, spacing: 8)), "1")
check("narrower than one minimum is still one column", String(DashboardRowHelpers.columnCount(availableWidth: 100, minimumColumnWidth: 165, spacing: 8)), "1")

// Whole rows only, with room kept for a "+N more" footer
func fit(_ heights: [CGFloat], columns: Int = 1, height: CGFloat, footer: CGFloat = 20) -> String {
    let result = DashboardRowHelpers.fitWholeRows(itemHeights: heights, columns: columns, spacing: 8, availableHeight: height, footerHeight: footer)
    return "\(result.shown)/\(result.hidden)"
}
func footerFits(_ heights: [CGFloat], columns: Int = 1, height: CGFloat) -> String {
    String(DashboardRowHelpers.fitWholeRows(itemHeights: heights, columns: columns, spacing: 8, availableHeight: height, footerHeight: 20).footerFits)
}
check("everything fits: nothing hidden, no footer space taken", fit([50, 50], height: 108), "2/0")
check("footer space forces a row off when it would not otherwise fit", fit([50, 50, 50], height: 120), "1/2")
check("three rows that exactly fit show no footer", fit([50, 50, 50], height: 166), "3/0")
check("a partial third row is never shown", fit([50, 50, 50], height: 150), "2/1")
check("always at least one row, even in a tiny card", fit([50, 50], height: 10), "1/1")
check("empty list", fit([], height: 100), "0/0")
check("two columns pair items into rows", fit([50, 50, 50, 50, 50], columns: 2, height: 200), "5/0")
check("two columns, footer takes the second row", fit([50, 50, 50, 50, 50], columns: 2, height: 108), "2/3")
check("a row is as tall as its tallest item", fit([40, 80, 40, 40], columns: 2, height: 100), "2/2")
check("exactly filling the height still fits", fit([50, 50], height: 108, footer: 0), "2/0")
check("one point short drops a row", fit([50, 50], height: 107), "1/1")
check("a zero-height card shows one row", fit([30, 30, 30], height: 0), "1/2")

// Estimating how many lines a title wraps to
func lines(_ chars: Int, width: CGFloat, maxLines: Int = 2) -> String {
    String(DashboardRowHelpers.estimatedLineCount(characterCount: chars, availableWidth: width, averageCharacterWidth: 9, maxLines: maxLines))
}
check("a short title is one line", lines(6, width: 100), "1")
check("a title longer than a line wraps to two", lines(18, width: 100), "2")
check("never more than the cap", lines(200, width: 100), "2")
check("a higher cap allows more lines", lines(30, width: 90, maxLines: 4), "3")
check("empty text is still one line", lines(0, width: 100), "1")
check("no measured width assumes the worst case", lines(5, width: 0), "2")
check("rows height: tallest per row plus gaps", String(Double(DashboardRowHelpers.rowsHeight(itemHeights: [40, 80, 30], columns: 2, spacing: 8))), "118.0")
check("rows height: single column stacks", String(Double(DashboardRowHelpers.rowsHeight(itemHeights: [40, 30], columns: 1, spacing: 8))), "78.0")
check("rows height: nothing", String(Double(DashboardRowHelpers.rowsHeight(itemHeights: [], columns: 2, spacing: 8))), "0.0")

check("footer fits when there is room under the rows", footerFits([50, 50, 50], height: 140), "true")
check("a lone forced row that fills the card leaves no room for the footer", footerFits([90, 90], height: 94), "false")
check("nothing hidden means the footer is not needed, so it trivially fits", footerFits([50], height: 20), "true")

// Wrapping a row of child chips
func chipRows(_ count: Int, width: CGFloat) -> String { String(DashboardRowHelpers.chipRowCount(count: count, availableWidth: width, chipSize: 32, spacing: 6)) }
check("two kids fit on one line", chipRows(2, width: 200), "1")
check("five kids fit on one line in a wide tile", chipRows(5, width: 200), "1")
check("five kids wrap in a narrow tile", chipRows(5, width: 150), "2")
check("eight kids wrap even in a wide tile", chipRows(8, width: 200), "2")
check("no kids, no rows", chipRows(0, width: 200), "0")
check("unmeasured width assumes one chip per line", chipRows(3, width: 0), "3")
check("a width narrower than one chip still places one per line", chipRows(3, width: 10), "3")

// Does everything really fit, with no forced row
func allFit(_ heights: [CGFloat], columns: Int = 1, height: CGFloat) -> String {
    String(DashboardRowHelpers.allFit(itemHeights: heights, columns: columns, spacing: 8, availableHeight: height))
}
check("two tall tiles in one row, in a card too short for them, do not fit", allFit([122, 122], columns: 2, height: 81), "false")
check("the same tiles in a tall enough card fit", allFit([122, 122], columns: 2, height: 122), "true")
check("exactly filling the height fits", allFit([50, 50], height: 108), "true")
check("one point short does not", allFit([50, 50], height: 107), "false")
check("nothing to show always fits", allFit([], height: 0), "true")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
