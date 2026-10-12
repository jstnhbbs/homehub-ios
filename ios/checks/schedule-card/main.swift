import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
// 2026-10-07 12:00 UTC.
let noon = Date(timeIntervalSince1970: 1_791_374_400)
func at(_ hour: Int, _ minutes: Int = 0, dayOffset: Int = 0) -> Date {
    noon.addingTimeInterval(TimeInterval((hour - 12) * 3600 + minutes * 60 + dayOffset * 86_400))
}
func event(_ title: String, from start: Date, minutes: Int = 60, allDay: Bool = false) -> ScheduleEvent {
    ScheduleEvent(eventId: title, title: title, startsAt: start, endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), allDay: allDay, color: nil, calendarName: nil)
}
func summary(today: [ScheduleEvent], tomorrow: [ScheduleEvent] = [], connected: Bool = true) -> ScheduleCardSummary {
    ScheduleCardSummary(today: today, tomorrow: tomorrow, now: noon, timezone: utc, isConnected: connected)
}
func titles(_ events: [ScheduleEvent]) -> String { events.map(\.title).joined(separator: ",") }

// MARK: the order

let mixed = summary(today: [event("dinner", from: at(18)), event("holiday", from: at(0), minutes: 1440, allDay: true), event("lunch", from: at(13)), event("breakfast", from: at(8))])
check("all-day first, finished ones gone, then by time", titles(mixed.todayLeft), "holiday,lunch,dinner")

// MARK: Small

check("next timed event's time", summary(today: [event("soccer", from: at(16))]).headline.hasSuffix("PM") ? "a time" : summary(today: [event("soccer", from: at(16))]).headline, "a time")
check("and its name", summary(today: [event("soccer", from: at(16))]).caption, "soccer")
check("an event on now", summary(today: [event("meeting", from: at(11, 30), minutes: 90)]).headline, "Now")
check("only an all-day event", summary(today: [event("holiday", from: at(0), minutes: 1440, allDay: true)]).headline, "All day")
let clearToday = summary(today: [event("breakfast", from: at(8))], tomorrow: [event("school", from: at(8, dayOffset: 1))])
check("nothing left today points at tomorrow", clearToday.headline, "Tomorrow")
check("and says what", clearToday.caption.hasPrefix("school · ") ? "yes" : clearToday.caption, "yes")
check("nothing at all", summary(today: []).headline, "Free")
check("nothing at all caption", summary(today: []).caption, "Nothing on the calendar")
check("not connected", summary(today: [], connected: false).headline, "Not connected")
check("not connected caption", summary(today: [], connected: false).caption, "Connect a calendar to see events")

// MARK: the line

check("one left", summary(today: [event("a", from: at(14))]).line, "1 event left today")
check("several left", summary(today: [event("a", from: at(14)), event("b", from: at(15))]).line, "2 events left today")
check("all over", clearToday.line, "Nothing left today")
check("an empty day", summary(today: []).line, "Nothing on the calendar today")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
