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
func next(chores: [ChoreRow] = [], events: [ScheduleEvent] = []) -> String {
    guard let item = NextUpSummary.next(chores: chores, events: events, profiles: [], todayDate: "2026-10-07", timezone: utc, now: noon) else { return "nothing" }
    return "\(item.eyebrow) | \(item.title) | \(item.detail)"
}

check("nothing at all", next(), "nothing")
check("an upcoming event", next(events: [event("Soccer", at(16))]), "NEXT · 4:00 PM | Soccer | Family")
check("a timed chore", next(chores: [chore("Trash", time: "21:00")]), "DUE · 9:00 PM | Trash | Anyone")
check("the soonest wins", next(chores: [chore("Trash", time: "21:00")], events: [event("Soccer", at(16))]), "NEXT · 4:00 PM | Soccer | Family")
check("a chore can come first", next(chores: [chore("Dishes", time: "14:00")], events: [event("Soccer", at(16))]), "DUE · 2:00 PM | Dishes | Anyone")
check("an event wins a tie", next(chores: [chore("Dishes", time: "16:00")], events: [event("Soccer", at(16))]), "NEXT · 4:00 PM | Soccer | Family")
check("what is on now comes first", next(chores: [chore("Dishes", time: "12:30")], events: [event("Meeting", at(11, 30), minutes: 90)]), "NOW | Meeting | Until 1:00 PM")
check("an event with no calendar name", next(events: [event("Soccer", at(16), calendar: nil)]), "NEXT · 4:00 PM | Soccer | Calendar")
check("a finished event is gone", next(events: [event("Breakfast", at(8))]), "nothing")
check("all-day events have no next", next(events: [event("Holiday", at(0), minutes: 1440, allDay: true)]), "nothing")
check("a chore with no time has no next", next(chores: [chore("Sweep", time: nil)]), "nothing")
check("a done chore is gone", next(chores: [chore("Trash", time: "21:00", done: true)]), "nothing")
check("a missed chore is called out when nothing is left", next(chores: [chore("Walk the dog", time: "08:00")]), "OVERDUE · 8:00 AM | Walk the dog | Anyone")
check("something still to come beats a missed chore", next(chores: [chore("Walk the dog", time: "08:00")], events: [event("Soccer", at(16))]), "NEXT · 4:00 PM | Soccer | Family")
check("the earliest missed chore", next(chores: [chore("B", time: "10:00"), chore("A", time: "08:00")]), "OVERDUE · 8:00 AM | A | Anyone")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
