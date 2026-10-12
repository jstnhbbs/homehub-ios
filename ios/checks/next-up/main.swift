import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    let normalized = actual.replacingOccurrences(of: "\u{202F}", with: " ")
    if normalized == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(normalized)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
// 2026-10-07 12:00 UTC.
let noon = Date(timeIntervalSince1970: 1_791_374_400)
func at(_ hour: Int, _ minutes: Int = 0) -> Date { noon.addingTimeInterval(TimeInterval((hour - 12) * 3600 + minutes * 60)) }
func event(_ title: String, _ start: Date, minutes: Int = 60, allDay: Bool = false, calendar: String? = "Family") -> ScheduleEvent {
    ScheduleEvent(eventId: title, title: title, startsAt: start, endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), allDay: allDay, color: nil, calendarName: calendar)
}
func chore(_ title: String, time: String?, done: Bool = false) -> ChoreRow {
    ChoreRow(id: title, title: title, profileId: nil, cadence: .daily, days: "0,1,2,3,4,5,6", sortOrder: nil, dueDate: nil, dueTime: time, repeatUnit: nil, repeatInterval: nil, periodKey: "k", completed: done, completedAt: nil, completedByName: nil, dueToday: true, overdue: nil, nextDueDate: nil)
}
func strip(chores: [ChoreRow] = [], events: [ScheduleEvent] = []) -> [String] {
    NextUpSummary.upcoming(chores: chores, events: events, profiles: [], todayDate: "2026-10-07", timezone: utc, now: noon)
        .map { "\($0.status) | \($0.title) | \($0.detail)" }
}
func check(_ label: String, _ actual: [String], _ expected: [String]) { check(label, actual.joined(separator: "\n"), expected.joined(separator: "\n")) }

check("nothing at all", strip(), [])
check("nothing close stays out of the way", strip(events: [event("Soccer", at(16))]), [])
check("an event within the hour shows", strip(events: [event("Soccer", at(12, 27))]), ["in 27 min | Soccer | 12:27 PM – 1:27 PM"])
check("exactly an hour away still shows", strip(events: [event("Soccer", at(13))]), ["in 1 hr | Soccer | 1:00 PM – 2:00 PM"])
check("just past the hour stays out", strip(events: [event("Soccer", at(13, 1))]), [])
check("a chore within the hour shows", strip(chores: [chore("Trash", time: "12:45")]), ["in 45 min | Trash | 12:45 PM"])
check("what is on now shows", strip(events: [event("Meeting", at(11, 30), minutes: 90)]), ["Now | Meeting | 11:30 AM – 1:00 PM"])
check("a missed chore shows", strip(chores: [chore("Walk the dog", time: "08:00")]), ["Overdue | Walk the dog | 8:00 AM"])
check("a done chore is gone", strip(chores: [chore("Trash", time: "12:30", done: true)]), [])
check("a finished event is gone", strip(events: [event("Breakfast", at(8))]), [])
check("all-day events have no next", strip(events: [event("Holiday", at(0), minutes: 1440, allDay: true)]), [])
check("a chore with no time has no next", strip(chores: [chore("Sweep", time: nil)]), [])

// Once it shows, what comes later is listed too, in time order.
check("what comes after rides along", strip(events: [event("Reading", at(11, 45), minutes: 60), event("Lunch", at(13, 30)), event("Soccer", at(16))]),
      ["Now | Reading | 11:45 AM – 12:45 PM", "in 1 hr 30 min | Lunch | 1:30 PM – 2:30 PM", "at 4:00 PM | Soccer | 4:00 PM – 5:00 PM"])
check("an event and a chore are one list", strip(chores: [chore("Dishes", time: "12:20")], events: [event("Soccer", at(12, 40))]),
      ["in 20 min | Dishes | 12:20 PM", "in 40 min | Soccer | 12:40 PM – 1:40 PM"])
check("an event goes before a chore at the same time", strip(chores: [chore("Dishes", time: "12:30")], events: [event("Soccer", at(12, 30))]),
      ["in 30 min | Soccer | 12:30 PM – 1:30 PM", "in 30 min | Dishes | 12:30 PM"])
check("at most three lines", strip(events: [event("A", at(12, 10)), event("B", at(12, 20)), event("C", at(12, 30)), event("D", at(12, 40))]).count == 3 ? ["3"] : ["not 3"], ["3"])
check("a missed chore comes first, and only the earliest", strip(chores: [chore("B", time: "10:00"), chore("A", time: "08:00")], events: [event("Soccer", at(12, 30))]),
      ["Overdue | A | 8:00 AM", "in 30 min | Soccer | 12:30 PM – 1:30 PM"])
check("a missed chore alone brings the rest of the day with it", strip(chores: [chore("A", time: "08:00")], events: [event("Soccer", at(16))]),
      ["Overdue | A | 8:00 AM", "at 4:00 PM | Soccer | 4:00 PM – 5:00 PM"])
let alex = Profile(id: "p1", householdId: "h", userId: nil, profileType: .adult, name: "Alex", color: "#6689a3", avatar: "", birthday: nil, sortOrder: 0, memberRole: nil, createdAt: nil, updatedAt: nil)
let alexsChore = ChoreRow(id: "c", title: "Trash", profileId: "p1", cadence: .daily, days: "0,1,2,3,4,5,6", sortOrder: nil, dueDate: nil, dueTime: "12:30", repeatUnit: nil, repeatInterval: nil, periodKey: "k", completed: false, completedAt: nil, completedByName: nil, dueToday: true, overdue: nil, nextDueDate: nil)
check("whose chore it is", NextUpSummary.upcoming(chores: [alexsChore], events: [], profiles: [alex], todayDate: "2026-10-07", timezone: utc, now: noon).map(\.detail), ["12:30 PM · Alex"])

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
