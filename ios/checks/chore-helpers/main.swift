import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
let us = Locale(identifier: "en_US")
let uk = Locale(identifier: "en_GB")

func detail(_ unit: ChoreRepeatUnit, _ interval: Int = 1, days: String = "0,1,2,3,4,5,6", date: String? = nil, cadence: ChoreCadence = .daily, locale: Locale = us) -> String {
    let rule = ChoreHelpers.repeatRule(unit: unit, interval: interval, cadence: cadence, days: days)
    return ChoreHelpers.repeatDetail(rule: rule, days: days, dueDate: date, timezone: chicago, locale: locale)
}

// The words for each repeat
check("never", detail(.never), "Doesn't repeat")
check("every day", detail(.day), "Every day")
check("weekdays", detail(.day, days: "1,2,3,4,5"), "Weekdays")
check("some days", detail(.day, days: "6,0"), "Every Sat, Sun")
check("every 3 days", detail(.day, 3), "Every 3 days")
check("every week names the day", detail(.week, days: "3"), "Every week · Wednesday")
check("every 2 weeks names the day", detail(.week, 2, days: "5"), "Every 2 weeks · Friday")
check("every month names the day of the month", detail(.month, date: "2026-10-15"), "Every month · on the 15th")
check("ordinals: 1st 2nd 3rd 22nd", [1, 2, 3, 22].map { detail(.month, date: "2026-10-\(String(format: "%02d", $0))") }.joined(separator: "|"),
      "Every month · on the 1st|Every month · on the 2nd|Every month · on the 3rd|Every month · on the 22nd")
check("every 3 months", detail(.month, 3, date: "2026-10-15"), "Every 3 months · on the 15th")
check("every year names the date", detail(.year, date: "2026-10-15"), "Every year · Oct 15")
check("every year, UK order", detail(.year, date: "2026-10-15", locale: uk), "Every year · 15 Oct")
check("month with no date still reads", detail(.month), "Every month")

// Rows from a server that predates repeat rules
check("old daily row", detail(nil, 1, cadence: .daily), "Every day")
check("old weekly row", detail(nil, 1, days: "3", cadence: .weekly), "Every week · Wednesday")
func detail(_ unit: ChoreRepeatUnit?, _ interval: Int, days: String = "0,1,2,3,4,5,6", cadence: ChoreCadence) -> String {
    let rule = ChoreHelpers.repeatRule(unit: unit, interval: interval, cadence: cadence, days: days)
    return ChoreHelpers.repeatDetail(rule: rule, days: days, dueDate: nil, timezone: chicago, locale: us)
}

// Presets
check("daily is a preset", ChoreRepeatPreset.matching(.daily).rawValue, "daily")
check("work week is its own preset", ChoreRepeatPreset.matching(.weekdaysOnly).rawValue, "weekdays")
check("every 2 weeks is a preset", ChoreRepeatPreset.matching(ChoreRepeatRule(unit: .week, interval: 2)).rawValue, "everyTwoWeeks")
check("every 3 months is a preset", ChoreRepeatPreset.matching(ChoreRepeatRule(unit: .month, interval: 3)).rawValue, "everyThreeMonths")
check("every 5 days is custom", ChoreRepeatPreset.matching(ChoreRepeatRule(unit: .day, interval: 5)).rawValue, "custom")
check("every 6 weeks is custom", ChoreRepeatPreset.matching(ChoreRepeatRule(unit: .week, interval: 6)).rawValue, "custom")
check("a daily row with every weekday listed is just daily",
      ChoreHelpers.repeatRule(unit: .day, interval: 1, cadence: .daily, days: "0,1,2,3,4,5,6") == .daily ? "daily" : "other", "daily")

// What needs a date
check("a one-off does not", String(ChoreHelpers.needsDate(.never)), "false")
check("daily does not", String(ChoreHelpers.needsDate(.daily)), "false")
check("weekly does", String(ChoreHelpers.needsDate(ChoreRepeatRule(unit: .week))), "true")
check("monthly does", String(ChoreHelpers.needsDate(ChoreRepeatRule(unit: .month))), "true")
check("every 3 days does", String(ChoreHelpers.needsDate(ChoreRepeatRule(unit: .day, interval: 3))), "true")

// What is sent
let weekly = ChoreHelpers.input(title: "Mow", profileId: nil, rule: ChoreRepeatRule(unit: .week, interval: 2), dueDate: "2026-10-07", dueTime: "09:00", weekDay: "3")
check("every 2 weeks sends weekly cadence for older servers", weekly.cadence.rawValue, "weekly")
check("...and the real rule", "\(weekly.repeatUnit!.rawValue) \(weekly.repeatInterval!) \(weekly.weekDay!)", "week 2 3")
let never = ChoreHelpers.input(title: "Fix", profileId: nil, rule: .never, dueDate: nil, dueTime: nil, weekDay: "3")
check("a one-off sends no interval or weekday", "\(String(describing: never.repeatInterval)) \(String(describing: never.weekDay))", "nil nil")
let work = ChoreHelpers.input(title: "Lunch", profileId: nil, rule: .weekdaysOnly, dueDate: nil, dueTime: nil, weekDay: "3")
check("weekdays sends the days, as a daily chore", "\(work.cadence.rawValue) \(work.weekdays!.joined(separator: ","))", "daily 1,2,3,4,5")
let plainDaily = ChoreHelpers.input(title: "Dog", profileId: nil, rule: .daily, dueDate: nil, dueTime: nil, weekDay: "3")
check("daily sends no weekdays", String(describing: plainDaily.weekdays), "nil")

// Times
check("US time", ChoreHelpers.timeLabel("17:30", locale: us), "5:30\u{202F}PM")
check("24-hour time", ChoreHelpers.timeLabel("17:30", locale: Locale(identifier: "en_GB")), "17:30")
check("midnight", ChoreHelpers.timeLabel("00:05", locale: Locale(identifier: "en_GB")), "00:05")
check("garbage is shown as is", ChoreHelpers.timeLabel("soon", locale: us), "soon")
check("minute of the day", String(describing: ChoreHelpers.minuteOfDay("17:30")), "Optional(1050)")
check("no minute for garbage", String(describing: ChoreHelpers.minuteOfDay("25:00")), "nil")

// The line under a chore
func row(unit: ChoreRepeatUnit?, dueDate: String? = nil, dueTime: String? = nil, overdue: Bool? = nil) -> ChoreRow {
    ChoreRow(id: "1", title: "T", profileId: nil, cadence: .daily, days: "0,1,2,3,4,5,6", sortOrder: 0, dueDate: dueDate, dueTime: dueTime, repeatUnit: unit, repeatInterval: 1, periodKey: "2026-10-07", completed: false, completedAt: nil, completedByName: nil, dueToday: true, overdue: overdue, nextDueDate: nil)
}
check("a one-off with a date", String(describing: ChoreHelpers.dueLine(for: row(unit: .never, dueDate: "2026-10-09"), timezone: chicago, locale: us)), "Optional(\"Due Fri, Oct 9\")")
check("a one-off with a date and time", String(describing: ChoreHelpers.dueLine(for: row(unit: .never, dueDate: "2026-10-09", dueTime: "17:30"), timezone: chicago, locale: Locale(identifier: "en_GB"))), "Optional(\"Due Fri 9 Oct · 17:30\")")
check("an overdue one-off", String(describing: ChoreHelpers.dueLine(for: row(unit: .never, dueDate: "2026-10-01", overdue: true), timezone: chicago, locale: us)), "Optional(\"Overdue · Thu, Oct 1\")")
check("a repeating chore with a time", String(describing: ChoreHelpers.dueLine(for: row(unit: .day, dueTime: "17:30"), timezone: chicago, locale: Locale(identifier: "en_GB"))), "Optional(\"Due by 17:30\")")
check("a repeating chore's start date is not a due date", String(describing: ChoreHelpers.dueLine(for: row(unit: .week, dueDate: "2026-01-07"), timezone: chicago, locale: us)), "nil")
check("a one-off with no date", String(describing: ChoreHelpers.dueLine(for: row(unit: .never), timezone: chicago, locale: us)), "nil")

// Decoding
let json = #"{"id":"1","title":"T","cadence":"weekly","days":"3","periodKey":"2026-W41","completed":false,"repeatUnit":"fortnight"}"#
let decoded = try! JSONDecoder().decode(ChoreRow.self, from: Data(json.utf8))
check("an unknown unit is read as daily, not an error", decoded.repeatUnit!.rawValue, "day")
let old = #"{"id":"1","title":"T","cadence":"weekly","days":"3","periodKey":"2026-W41","completed":false}"#
check("a row from an older server has no unit", String(describing: try! JSONDecoder().decode(ChoreRow.self, from: Data(old.utf8)).repeatUnit), "nil")

// Who a chore can be given to
func profile(_ type: ProfileType, userId: String?, role: String?) -> Profile {
    Profile(id: "p", householdId: "h", userId: userId, profileType: type, name: "N", color: "#000", avatar: "", birthday: nil, sortOrder: 0, memberRole: role, createdAt: nil, updatedAt: nil)
}
check("a child", String(profile(.child, userId: nil, role: nil).canBeAssignedChores), "true")
check("a parent", String(profile(.adult, userId: "u", role: "parent").canBeAssignedChores), "true")
check("an owner", String(profile(.adult, userId: "u", role: "owner").canBeAssignedChores), "true")
check("a guest", String(profile(.adult, userId: "u", role: "guest").canBeAssignedChores), "false")
check("a grown-up with no account here", String(profile(.adult, userId: nil, role: nil).canBeAssignedChores), "false")
check("an account whose role an older server did not send", String(profile(.adult, userId: "u", role: nil).canBeAssignedChores), "true")

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall chore helper checks passed")
