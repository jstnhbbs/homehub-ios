import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// Reading and writing
check("parse", RoutineDays.storage(RoutineDays.parse("5,1,3")), "1,3,5")
check("nothing readable is every day", RoutineDays.storage(RoutineDays.parse("")), "0,1,2,3,4,5,6")
check("junk is ignored", RoutineDays.storage(RoutineDays.parse("1,x,9,3")), "1,3")
check("only junk is every day", RoutineDays.storage(RoutineDays.parse("x,9")), "0,1,2,3,4,5,6")

// Words
check("every day", RoutineDays.summary("0,1,2,3,4,5,6"), "Every day")
check("weekdays", RoutineDays.summary("1,2,3,4,5"), "Weekdays")
check("weekends", RoutineDays.summary("6,0"), "Weekends")
check("some days, Monday first", RoutineDays.summary("5,1,3"), "Mon, Wed, Fri")
check("Sunday last in a list", RoutineDays.summary("0,2"), "Tue, Sun")

// Order of the chips
check("week starting Sunday", RoutineDays.ordered(weekStartsOn: 0).map(String.init).joined(), "0123456")
check("week starting Monday", RoutineDays.ordered(weekStartsOn: 1).map(String.init).joined(), "1234560")
check("week starting Saturday", RoutineDays.ordered(weekStartsOn: 6).map(String.init).joined(), "6012345")
check("names", "\(RoutineDays.shortName(1)) \(RoutineDays.fullName(1)) \(RoutineDays.shortName(0))", "Mo Monday Su")

// Which dates a routine runs on (2026-10-05 is a Monday)
check("Monday on a weekday routine", String(RoutineDays.runsOn("1,2,3,4,5", localDate: "2026-10-05")), "true")
check("Saturday on a weekday routine", String(RoutineDays.runsOn("1,2,3,4,5", localDate: "2026-10-10")), "false")
check("Sunday on a weekend routine", String(RoutineDays.runsOn("0,6", localDate: "2026-10-11")), "true")
check("a month boundary", String(RoutineDays.runsOn("4", localDate: "2026-12-31")), "true") // Thursday
check("an unreadable date runs", String(RoutineDays.runsOn("1", localDate: "soon")), "true")

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall routine day checks passed")
