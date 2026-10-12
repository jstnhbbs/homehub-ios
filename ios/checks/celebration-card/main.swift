import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
func item(_ name: String, next: String, days: Int, age: Int, kind: CelebrationKind = .birthday) -> BirthdayItem {
    BirthdayItem(id: name, source: .family, profileId: nil, name: name, birthDate: "1990-01-01", color: "#d87861", avatar: nil, notes: nil, giftIdeas: nil, notifyDaysBefore: 0, nextDate: next, daysUntil: days, upcomingAge: age, kind: kind)
}
func summary(_ items: [BirthdayItem]) -> CelebrationCardSummary {
    CelebrationCardSummary(items: items, todayDate: "2026-10-07", timezone: utc)
}
func shape(_ entries: [CelebrationEntry]) -> String {
    entries.map { entry -> String in
        switch entry {
        case .header(let month): "[\(month)]"
        case .item(let item): item.name
        }
    }.joined(separator: " ")
}

let upcoming = [item("Rosa", next: "2026-10-15", days: 8, age: 70), item("Maya", next: "2026-10-19", days: 12, age: 5), item("Sam", next: "2026-12-02", days: 56, age: 36), item("Leo", next: "2027-01-09", days: 94, age: 2)]
let s = summary(upcoming)

// MARK: Small

check("headline counts the days", s.headline, "8 days")
check("caption names them and their age", s.caption, "Rosa · turns 70")
check("tomorrow", summary([item("Rosa", next: "2026-10-08", days: 1, age: 70)]).headline, "Tomorrow")
check("today", summary([item("Rosa", next: "2026-10-07", days: 0, age: 70)]).headline, "Today")
check("an anniversary says years", summary([item("Us", next: "2026-10-15", days: 8, age: 9, kind: .anniversary)]).caption, "Us · 9 years")
check("no age known", summary([item("Rosa", next: "2026-10-15", days: 8, age: 0)]).caption, "Rosa")
check("nothing", summary([]).headline, "None soon")
check("nothing caption", summary([]).caption, "Add a birthday or anniversary")

// MARK: the line

check("a count for the month ahead", s.line, "2 in the next 30 days")
check("today comes first", summary([item("Rosa", next: "2026-10-07", days: 0, age: 70)]).line, "1 today")
check("nothing close", summary([item("Sam", next: "2026-12-02", days: 56, age: 36)]).line, "None in the next 30 days")
check("nothing at all", summary([]).line, "Nothing coming up")

// MARK: months

check("grouped by month, other years named", shape(s.entries), "[October] Rosa Maya [December] Sam [January 2027] Leo")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
