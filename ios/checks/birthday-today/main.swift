import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func item(_ id: String, _ name: String, next: String, age: Int = 6) -> BirthdayItem {
    BirthdayItem(
        id: id, source: .profile, profileId: nil, name: name, birthDate: "2020-09-18", color: "#4f7c6d",
        avatar: nil, notes: nil, giftIdeas: nil, notifyDaysBefore: 7, nextDate: next, daysUntil: 0, upcomingAge: age
    )
}

let all = [
    item("a", "Noah", next: "2026-09-18"),
    item("b", "emma", next: "2026-09-18", age: 8),
    item("c", "Ava", next: "2026-09-19"),
    item("d", "Liam", next: "2026-10-30"),
]
check("only today's birthdays", BirthdayToday.items(all, today: "2026-09-18").map(\.name).joined(separator: ","), "emma,Noah")
check("nobody today", BirthdayToday.items(all, today: "2026-09-20").map(\.name).joined(separator: ","), "")
check("a stale dashboard rolls over at midnight", BirthdayToday.items(all, today: "2026-09-19").map(\.name).joined(separator: ","), "Ava")
check("yesterday's birthday is over", BirthdayToday.items(all, today: "2026-09-19").contains { $0.name == "Noah" } ? "shown" : "gone", "gone")

check("headline", BirthdayToday.headline(name: "Emma"), "Happy birthday, Emma!")
check("anniversary headline", BirthdayToday.headline(name: "Alex & Sam", kind: .anniversary), "Happy anniversary, Alex & Sam!")
check("anniversary years", String(describing: BirthdayToday.ageLine(10, kind: .anniversary)), "Optional(\"10 years today\")")
check("first anniversary", String(describing: BirthdayToday.ageLine(1, kind: .anniversary)), "Optional(\"1 year today\")")
check("anniversary with no year", String(describing: BirthdayToday.ageLine(0, kind: .anniversary)), "nil")
check("age line", String(describing: BirthdayToday.ageLine(6)), "Optional(\"Turning 6 today\")")
check("age 1", String(describing: BirthdayToday.ageLine(1)), "Optional(\"Turning 1 today\")")
check("no age when zero", String(describing: BirthdayToday.ageLine(0)), "nil")
check("no age when negative", String(describing: BirthdayToday.ageLine(-3)), "nil")
check("no age when absurd", String(describing: BirthdayToday.ageLine(2026)), "nil")

let defaults = UserDefaults(suiteName: "beacon.birthday.checks.\(UUID().uuidString)")!
check("not celebrated at first", String(BirthdayToday.hasCelebrated(id: "a", localDate: "2026-09-18", defaults: defaults)), "false")
BirthdayToday.markCelebrated(id: "a", localDate: "2026-09-18", defaults: defaults)
check("celebrated once today", String(BirthdayToday.hasCelebrated(id: "a", localDate: "2026-09-18", defaults: defaults)), "true")
check("someone else is separate", String(BirthdayToday.hasCelebrated(id: "b", localDate: "2026-09-18", defaults: defaults)), "false")
check("next year is a new celebration", String(BirthdayToday.hasCelebrated(id: "a", localDate: "2027-09-18", defaults: defaults)), "false")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
