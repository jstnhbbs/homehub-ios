import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = chicago
let us = Locale(identifier: "en_US")

func at(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.timeZone = chicago
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: text)!
}
func text(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = chicago
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}
func row(_ id: String, time: String?, completed: Bool = false, dueToday: Bool? = nil) -> ChoreRow {
    ChoreRow(id: id, title: "Chore \(id)", profileId: nil, cadence: .daily, days: "0,1,2,3,4,5,6", sortOrder: 0, dueDate: nil, dueTime: time, repeatUnit: .day, repeatInterval: 1, periodKey: "2026-10-07", completed: completed, completedAt: nil, completedByName: nil, dueToday: dueToday, overdue: nil, nextDueDate: nil)
}
func ahead(_ id: String, _ date: String, _ time: String) -> UpcomingChore {
    UpcomingChore(id: id, title: "Chore \(id)", profileId: nil, date: date, dueTime: time, periodKey: date)
}
func plan(today: [ChoreRow] = [], upcoming: [UpcomingChore] = [], lead: Int = 0, now: String = "2026-10-07 06:00") -> [ChoreReminder] {
    ChoreReminderPlanner.reminders(today: today, upcoming: upcoming, localDate: "2026-10-07", leadMinutes: lead, now: at(now), calendar: calendar, locale: us)
}
func summary(_ reminders: [ChoreReminder]) -> String {
    reminders.map { "\($0.id)@\(text($0.fireDate))" }.joined(separator: " ")
}

// Today
check("a timed chore reminds at its time", summary(plan(today: [row("a", time: "17:30")])), "chore.a.2026-10-07@2026-10-07 17:30")
check("a chore with no time is left to the check-in", summary(plan(today: [row("a", time: nil)])), "")
check("a finished chore does not remind", summary(plan(today: [row("a", time: "17:30", completed: true)])), "")
check("a chore not due today does not remind", summary(plan(today: [row("a", time: "17:30", dueToday: false)])), "")
check("a time that has passed does not remind", summary(plan(today: [row("a", time: "05:00")])), "")

// Ahead
check("tomorrow's chore is planned before the day", summary(plan(upcoming: [ahead("a", "2026-10-08", "07:00")])), "chore.a.2026-10-08@2026-10-08 07:00")
check("the same chore on two days has two reminders", summary(plan(today: [row("a", time: "07:00")], upcoming: [ahead("a", "2026-10-08", "07:00")], now: "2026-10-07 05:00")),
      "chore.a.2026-10-07@2026-10-07 07:00 chore.a.2026-10-08@2026-10-08 07:00")

// What a Done button needs
let withButtons = plan(today: [row("a", time: "17:30")], upcoming: [ahead("b", "2026-10-08", "07:00")])
check("a reminder knows its chore and period", withButtons.map { "\($0.choreId)@\($0.periodKey)" }.joined(separator: " "), "a@2026-10-07 b@2026-10-08")

// Lead time
check("15 minutes before", summary(plan(today: [row("a", time: "17:30")], lead: 15)), "chore.a.2026-10-07@2026-10-07 17:15")
check("an hour before a morning chore reaches into the early morning", summary(plan(upcoming: [ahead("a", "2026-10-08", "00:30")], lead: 60)), "chore.a.2026-10-08@2026-10-07 23:30")
check("lead body names the time", plan(today: [row("a", time: "17:30")], lead: 15)[0].body, "Due at 5:30\u{202F}PM.")
check("no lead says it is due now", plan(today: [row("a", time: "17:30")], lead: 0)[0].body, "This chore is due now.")
check("inside the lead time, it reminds at the time instead", summary(plan(today: [row("a", time: "06:10")], lead: 30, now: "2026-10-07 06:00")), "chore.a.2026-10-07@2026-10-07 06:10")
check("...and says it is due now", plan(today: [row("a", time: "06:10")], lead: 30, now: "2026-10-07 06:00")[0].body, "This chore is due now.")

// Daylight saving: clocks go back on 2026-11-01 in Chicago, so 07:00 stays 07:00 on the wall
let dst = ChoreReminderPlanner.reminders(today: [], upcoming: [ahead("a", "2026-11-02", "07:00")], localDate: "2026-11-01", leadMinutes: 0, now: at("2026-11-01 12:00"), calendar: calendar, locale: us)
check("a time stays the same on the clock across a clock change", summary(dst), "chore.a.2026-11-02@2026-11-02 07:00")

// Labels
check("labels", ChoreReminderPlanner.leadChoices.map(ChoreReminderPlanner.leadLabel).joined(separator: " | "),
      "At the Time | 5 Minutes Before | 10 Minutes Before | 15 Minutes Before | 30 Minutes Before | 1 Hour Before | 2 Hours Before")

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall chore reminder checks passed")
