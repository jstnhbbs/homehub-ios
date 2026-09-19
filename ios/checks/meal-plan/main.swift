import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let now = DateHelpers.dateFromLocalDate("2026-09-18", timezone: chicago)!

// Drag tokens
let ref = MealSlotRef(localDate: "2026-09-18", slot: .dinner)
check("token", ref.token, "beacon.meal:2026-09-18:dinner")
check("token round trip", String(describing: MealSlotRef(token: ref.token) == ref), "true")
check("wrong prefix rejected", String(describing: MealSlotRef(token: "hello:2026-09-18:dinner")), "nil")
check("plain text rejected", String(describing: MealSlotRef(token: "some dragged text")), "nil")
check("bad slot rejected", String(describing: MealSlotRef(token: "beacon.meal:2026-09-18:brunch")), "nil")
check("extra part rejected", String(describing: MealSlotRef(token: "beacon.meal:2026-09-18:dinner:x")), "nil")
check("short date rejected", String(describing: MealSlotRef(token: "beacon.meal:9-18:dinner")), "nil")

// Title cleanup matches the server
check("normalize trims and drops blanks", MealPlanHelpers.normalizedTitle("  Tacos \n\n  Rice  \n"), "Tacos\nRice")
check("normalize blank", MealPlanHelpers.normalizedTitle(" \n  "), "")

// Date shifting
check("+1 day", MealPlanHelpers.date("2026-09-18", adding: 1, timezone: chicago), "2026-09-19")
check("+7 days", MealPlanHelpers.date("2026-09-18", adding: 7, timezone: chicago), "2026-09-25")
check("-7 days", MealPlanHelpers.date("2026-09-18", adding: -7, timezone: chicago), "2026-09-11")
check("month end", MealPlanHelpers.date("2026-09-30", adding: 1, timezone: chicago), "2026-10-01")
check("year end", MealPlanHelpers.date("2026-12-31", adding: 1, timezone: chicago), "2027-01-01")
check("leap day", MealPlanHelpers.date("2028-02-28", adding: 1, timezone: chicago), "2028-02-29")
check("DST spring forward", MealPlanHelpers.date("2026-03-08", adding: 1, timezone: chicago), "2026-03-09")
check("DST fall back", MealPlanHelpers.date("2026-11-01", adding: 1, timezone: chicago), "2026-11-02")
check("DST week span", MealPlanHelpers.date("2026-03-04", adding: 7, timezone: chicago), "2026-03-11")
check("other timezone", MealPlanHelpers.date("2026-09-18", adding: 1, timezone: tokyo), "2026-09-19")
check("garbage date passes through", MealPlanHelpers.date("nope", adding: 1, timezone: chicago), "nope")

// Week labels
check("same month", MealPlanHelpers.weekRangeLabel(first: "2026-09-14", last: "2026-09-20", timezone: chicago, now: now), "Sep 14 – 20")
check("across months", MealPlanHelpers.weekRangeLabel(first: "2026-09-28", last: "2026-10-04", timezone: chicago, now: now), "Sep 28 – Oct 4")
check("other year shows year", MealPlanHelpers.weekRangeLabel(first: "2027-01-04", last: "2027-01-10", timezone: chicago, now: now), "Jan 4 – 10, 2027")
check("across years", MealPlanHelpers.weekRangeLabel(first: "2026-12-28", last: "2027-01-03", timezone: chicago, now: now), "Dec 28 – Jan 3, 2027")

// Recents
func meal(_ date: String, _ slot: MealSlot, _ title: String, recipe: String? = nil) -> Meal {
    Meal(localDate: date, slot: slot, title: title, recipeId: recipe)
}
let pool = [
    meal("2026-09-10", .dinner, "Tacos", recipe: "r-tacos"),
    meal("2026-09-16", .dinner, "Tacos", recipe: "r-tacos"),
    meal("2026-09-16", .lunch, "Leftover soup"),
    meal("2026-09-17", .snack, "Popcorn"),
    meal("2026-09-17", .breakfast, "Pancakes", recipe: "r-pancakes"),
    meal("2026-09-14", .lunch, "leftover SOUP"),
    meal("2026-09-15", .dinner, "  "),
]
let recents = MealPlanHelpers.recentMeals(from: pool)
check("recents order and dedupe", recents.map(\.title).joined(separator: " | "), "Pancakes | Tacos | Leftover soup")
check("snacks and blanks excluded", String(describing: recents.contains { $0.title == "Popcorn" || $0.title.trimmingCharacters(in: .whitespaces).isEmpty }), "false")
check("same-day dinner before lunch", MealPlanHelpers.recentMeals(from: [meal("2026-09-16", .lunch, "Soup"), meal("2026-09-16", .dinner, "Pasta")]).map(\.title).joined(separator: " | "), "Pasta | Soup")
check("limit", String(MealPlanHelpers.recentMeals(from: (1...20).map { meal(String(format: "2026-09-%02d", $0), .dinner, "Meal \($0)") }, limit: 5).count), "5")
check("optimistic meal id", meal("2026-09-18", .dinner, "X").id, "2026-09-18-dinner")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
