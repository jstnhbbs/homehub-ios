import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func item(_ card: DashboardCardId, _ size: DashboardCardSize) -> DashboardGridItem {
    DashboardGridItem(card: card, columns: size.columns, rows: size.rows)
}
/// "schedule@0,0 2x2" for each card, in the order given.
func describe(_ result: DashboardGridPacker.Result) -> String {
    result.placements.map { "\($0.card.rawValue)@\($0.column),\($0.row) \($0.columns)x\($0.rows)" }.joined(separator: " ")
}

// MARK: sizes

check("small is one cell", "\(DashboardCardSize.small.columns)x\(DashboardCardSize.small.rows)", "1x1")
check("medium is two wide", "\(DashboardCardSize.medium.columns)x\(DashboardCardSize.medium.rows)", "2x1")
check("large is two by two", "\(DashboardCardSize.large.columns)x\(DashboardCardSize.large.rows)", "2x2")
check("saved 'standard' reads as small", DashboardCardSize(stored: "standard")?.rawValue ?? "nil", "small")
check("saved 'compact' reads as small", DashboardCardSize(stored: "compact")?.rawValue ?? "nil", "small")
check("saved 'expanded' reads as medium", DashboardCardSize(stored: "expanded")?.rawValue ?? "nil", "medium")
check("new names read as themselves", ["small", "medium", "large"].compactMap { DashboardCardSize(stored: $0)?.rawValue }.joined(separator: ","), "small,medium,large")
check("an unknown size is nil", String(DashboardCardSize(stored: "huge") == nil), "true")
check("every card can be large, sleep included", DashboardCardId.sleep.clamped(.large).rawValue, "large")
check("schedule can be large", DashboardCardId.schedule.clamped(.large).rawValue, "large")

// MARK: packing

let four = DashboardGridPacker.pack([item(.schedule, .small), item(.routines, .small), item(.chores, .small), item(.meals, .small), item(.snacks, .small)], columnCount: 4)
check("small cards fill a row, then the next", describe(four),
      "schedule@0,0 1x1 routines@1,0 1x1 chores@2,0 1x1 meals@3,0 1x1 snacks@0,1 1x1")
check("five small cards take two rows", String(four.rowCount), "2")

let mixed = DashboardGridPacker.pack([item(.schedule, .large), item(.routines, .medium), item(.chores, .small), item(.sleep, .small)], columnCount: 4)
check("a large card takes two columns and two rows, the rest sit beside it", describe(mixed),
      "schedule@0,0 2x2 routines@2,0 2x1 chores@2,1 1x1 sleep@3,1 1x1")
check("that fits in two rows", String(mixed.rowCount), "2")

let hole = DashboardGridPacker.pack([item(.schedule, .small), item(.routines, .medium), item(.chores, .small), item(.meals, .small)], columnCount: 3)
check("a later small card fills the gap a medium one left", describe(hole),
      "schedule@0,0 1x1 routines@1,0 2x1 chores@0,1 1x1 meals@1,1 1x1")

let narrow = DashboardGridPacker.pack([item(.schedule, .large), item(.routines, .small)], columnCount: 1)
check("on one column a large card is full width and two rows", describe(narrow), "schedule@0,0 1x2 routines@0,2 1x1")
check("and the next card goes under it", String(narrow.rowCount), "3")

let two = DashboardGridPacker.pack([item(.schedule, .medium), item(.routines, .small), item(.chores, .small)], columnCount: 2)
check("on two columns a medium card is the whole row", describe(two), "schedule@0,0 2x1 routines@0,1 1x1 chores@1,1 1x1")

let none = DashboardGridPacker.pack([], columnCount: 4)
check("nothing to place", String(none.rowCount), "0")

// MARK: column count

let nine = [DashboardCardId.schedule, .routines, .chores, .meals, .snacks, .sleep, .groceries, .birthdays, .notes].map { item($0, .small) }
let wide = DashboardGridPacker.columnCount(widthCap: 4, items: nine, size: CGSize(width: 1100, height: 700), spacing: 16)
check("nine small cards on a wide iPad make a three by three", String(wide), "3")
let fewTall = DashboardGridPacker.columnCount(widthCap: 4, items: Array(nine.prefix(2)), size: CGSize(width: 1100, height: 700), spacing: 16)
check("two small cards do not spread over four columns", String(fewTall), "2")
let widest = DashboardGridPacker.columnCount(widthCap: 4, items: [item(.schedule, .medium)], size: CGSize(width: 1100, height: 700), spacing: 16)
check("a medium card needs at least two columns", String(max(2, widest) == widest ? 1 : 0), "1")
check("one column when the page only has one", String(DashboardGridPacker.columnCount(widthCap: 1, items: nine, size: CGSize(width: 400, height: 700), spacing: 16)), "1")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
