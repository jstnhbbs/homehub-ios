import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}
func minute(_ h: Int, _ m: Int) -> Int { h * 60 + m }
func name(_ h: Int, _ m: Int) -> String { MealSlotClock.slot(minuteOfDay: minute(h, m)).rawValue }

check("midnight is breakfast", name(0, 0), "breakfast")
check("7:00 AM", name(7, 0), "breakfast")
check("10:29 AM is still breakfast", name(10, 29), "breakfast")
check("10:30 AM switches to lunch", name(10, 30), "lunch")
check("noon", name(12, 0), "lunch")
check("2:29 PM is still lunch", name(14, 29), "lunch")
check("2:30 PM switches to dinner", name(14, 30), "dinner")
check("3:14 PM (the screenshot) is dinner", name(15, 14), "dinner")
check("6:00 PM", name(18, 0), "dinner")
check("8:59 PM", name(20, 59), "dinner")
check("9:00 PM stays on dinner", name(21, 0), "dinner")
check("11:59 PM stays on dinner", name(23, 59), "dinner")

// Household clock, not the device's: the same instant is a different meal in different zones.
func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
let chicago = TimeZone(identifier: "America/Chicago")!
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let instant = iso("2026-09-25T20:14:00Z")   // 3:14 PM Chicago, 5:14 AM next day Tokyo
check("3:14 PM in Chicago", MealSlotClock.slot(at: instant, timezone: chicago).rawValue, "dinner")
check("same instant in Tokyo is early morning", MealSlotClock.slot(at: instant, timezone: tokyo).rawValue, "breakfast")
check("exactly 10:30 Chicago (CDT)", MealSlotClock.slot(at: iso("2026-09-25T15:30:00Z"), timezone: chicago).rawValue, "lunch")
check("one minute earlier", MealSlotClock.slot(at: iso("2026-09-25T15:29:00Z"), timezone: chicago).rawValue, "breakfast")
// The same wall-clock time either side of the fall-back on Nov 1 gives the same answer.
check("10:30 Chicago after DST ends", MealSlotClock.slot(at: iso("2026-11-02T16:30:00Z"), timezone: chicago).rawValue, "lunch")
check("10:29 Chicago after DST ends", MealSlotClock.slot(at: iso("2026-11-02T16:29:00Z"), timezone: chicago).rawValue, "breakfast")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
