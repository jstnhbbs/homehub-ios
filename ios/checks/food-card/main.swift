import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
func dinner(_ date: String, _ title: String) -> Meal { Meal(localDate: date, slot: .dinner, title: title) }
// 2026-10-07 is a Wednesday.
func summary(today: String = "2026-10-07", weekStartsOn: Int = 1, meals: [Meal] = [], upcoming: [Meal] = []) -> FoodCardSummary {
    FoodCardSummary(todayDate: today, timezone: utc, weekStartsOn: weekStartsOn, today: meals, upcomingDinners: upcoming)
}
func days(_ s: FoodCardSummary) -> String { s.rest.map { s.weekday($0) }.joined(separator: ",") }

// MARK: Small

check("tonight's dish", summary(meals: [dinner("2026-10-07", "Sheet Pan Fajitas\nwith rice")]).headline, "Sheet Pan Fajitas")
check("tonight's caption", summary().caption, "Dinner tonight")
check("no dinner planned", summary(meals: [Meal(localDate: "2026-10-07", slot: .lunch, title: "Soup")]).headline, "Not planned")
check("the line names the day", summary().line, "Today · Wednesday")

// MARK: which meals first

func order(_ hour: Int) -> String { FoodCardSummary.slotsByRelevance(hour: hour).map(\.rawValue).joined(separator: ",") }
check("in the morning, the day in order", order(8), "breakfast,lunch,dinner")
check("after breakfast, lunch and dinner lead", order(11), "lunch,dinner,breakfast")
check("in the afternoon, dinner leads", order(15), "dinner,breakfast,lunch")
check("late, everything is over and the day is in order", order(22), "breakfast,lunch,dinner")

// MARK: the rest of the week

check("Monday-start week, on a Wednesday", days(summary()), "Thu,Fri,Sat,Sun")
check("Sunday-start week, on a Wednesday", days(summary(weekStartsOn: 0)), "Thu,Fri,Sat")
check("the title", summary().restTitle, "Rest of the week")
check("on the last day of a Monday-start week, next week", days(summary(today: "2026-10-11")), "Mon,Tue,Wed,Thu,Fri,Sat,Sun")
check("and it says so", summary(today: "2026-10-11").restTitle, "Next week")
check("on the first day of a Monday-start week, six days", days(summary(today: "2026-10-05")), "Tue,Wed,Thu,Fri,Sat,Sun")
check("on the last day of a Sunday-start week", days(summary(today: "2026-10-10", weekStartsOn: 0)), "Sun,Mon,Tue,Wed,Thu,Fri,Sat")

// MARK: their dinners

let planned = summary(upcoming: [dinner("2026-10-09", "Tacos"), dinner("2026-10-11", "Pizza")])
check("days with a dinner have it, others have none", planned.rest.map { FoodCardSummary.dish($0.dinner) ?? "-" }.joined(separator: ","), "-,Tacos,-,Pizza")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
