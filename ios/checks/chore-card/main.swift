import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
func chore(_ title: String, done: Bool = false, time: String? = nil, overdue: Bool = false, next: String? = nil) -> ChoreRow {
    ChoreRow(
        id: title, title: title, profileId: nil, cadence: .daily, days: "0,1,2,3,4,5,6", sortOrder: nil,
        dueDate: nil, dueTime: time, repeatUnit: nil, repeatInterval: nil, periodKey: "k", completed: done,
        completedAt: nil, completedByName: nil, dueToday: next == nil, overdue: overdue, nextDueDate: next
    )
}
func summary(_ today: [ChoreRow], later: [ChoreRow] = []) -> ChoreCardSummary {
    // 2026-10-07 is a Wednesday.
    ChoreCardSummary(today: today, later: later, todayDate: "2026-10-07", timezone: utc)
}
func titles(_ rows: [ChoreRow]) -> String { rows.map(\.title).joined(separator: ",") }

// MARK: wording

let some = summary([chore("a"), chore("b", done: true), chore("c")])
check("headline counts what is left", some.headline, "2 left")
check("the line adds what is done", some.line, "2 left · 1 done")
check("progress is the share done", String(format: "%.2f", some.progress ?? -1), "0.33")

let none = summary([])
check("nothing due", none.headline, "None today")
check("nothing due line", none.line, "Nothing due today")
check("no progress bar when nothing is due", String(none.progress == nil), "true")

let all = summary([chore("a", done: true), chore("b", done: true)])
check("all done", all.headline, "All done")
check("all done line", all.line, "All 2 done")
check("all done caption", all.caption, "Nice work")
check("one chore done line", summary([chore("a", done: true)]).line, "1 chore done")
check("only some left has no done count when none are done", summary([chore("a"), chore("b")]).line, "2 left")

// MARK: order

let mixed = summary([chore("plain"), chore("evening", time: "21:00"), chore("morning", time: "07:30"), chore("late", time: "08:00", overdue: true)])
check("late first, then by time, then the rest", titles(mixed.pending), "late,morning,evening,plain")
check("plain chores keep their order", titles(summary([chore("x"), chore("y"), chore("z")]).pending), "x,y,z")
check("done ones are not pending", titles(summary([chore("a", done: true), chore("b")]).pending), "b")

// MARK: the next one

check("next, with its time", summary([chore("Trash", time: "21:00")]).caption.hasPrefix("Next: Trash · ") ? "yes" : summary([chore("Trash", time: "21:00")]).caption, "yes")
check("next, with no time", summary([chore("Trash")]).caption, "Next: Trash")
check("late is called out", summary([chore("Trash", time: "08:00", overdue: true)]).caption, "Overdue: Trash")

// MARK: coming up

let tomorrow = chore("Dishes", next: "2026-10-08")
let saturday = chore("Vacuum", next: "2026-10-10")
let s = summary([], later: [tomorrow, saturday])
check("tomorrow is named", s.dayLabel(for: tomorrow), "Tomorrow")
check("later days are weekdays", s.dayLabel(for: saturday), "Sat")
check("a clear day points at what is coming", s.caption, "Next: Dishes · Tomorrow")
check("no next day", s.dayLabel(for: chore("x")), "Soon")
check("coming-up subtitle is the person", s.laterSubtitle(for: saturday, assignee: "Maya") ?? "nil", "Maya")
check("coming-up subtitle with nothing to say", s.laterSubtitle(for: saturday, assignee: nil) ?? "nil", "nil")
check("the chip shows the weekday, tomorrow too", s.weekdayLabel(for: tomorrow), "Thu")
check("tomorrow is known", String(s.isTomorrow(tomorrow)), "true")
check("saturday is not tomorrow", String(s.isTomorrow(saturday)), "false")
check("coming-up subtitle with a time and a person", (s.laterSubtitle(for: chore("Mow", time: "09:00", next: "2026-10-09"), assignee: "Leo") ?? "").hasPrefix("Leo · ") ? "yes" : "no", "yes")
check("coming-up subtitle with only a time", (s.laterSubtitle(for: chore("Mow", time: "09:00", next: "2026-10-09"), assignee: nil) ?? "").isEmpty ? "empty" : "has a time", "has a time")

// MARK: names beside a dot

let people = ["Alex Rivera", "Sam Rivera", "Maya", "Sam Lee"]
check("a first name is enough", ChoreCardSummary.shortName("Alex Rivera", among: people), "Alex")
check("a single name stays", ChoreCardSummary.shortName("Maya", among: people), "Maya")
check("two people with the same first name keep their whole names", ChoreCardSummary.shortName("Sam Rivera", among: people), "Sam Rivera")
check("and the other Sam too", ChoreCardSummary.shortName("Sam Lee", among: people), "Sam Lee")
check("the same person on two chores is still one person", ChoreCardSummary.shortName("Alex Rivera", among: ["Alex Rivera", "Alex Rivera", "Maya"]), "Alex")
check("coming-up caption with nothing coming", summary([]).caption, "Nothing scheduled")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
