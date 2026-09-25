import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
let us = Locale(identifier: "en_US")
func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
/// Local wall-clock time of a date in Chicago, e.g. "2026-09-25 08:00".
func local(_ date: Date, _ tz: TimeZone = chicago) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = tz; f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: date)
}
func item(_ id: String, _ name: String, next: String, age: Int = 6, kind: CelebrationKind = .birthday) -> BirthdayItem {
    BirthdayItem(id: id, source: .profile, profileId: nil, name: name, birthDate: "2020-09-25", color: "#4f7c6d",
                 avatar: nil, notes: nil, giftIdeas: nil, notifyDaysBefore: 7, nextDate: next, daysUntil: 0, upcomingAge: age, kind: kind)
}
func plan(_ items: [BirthdayItem], onTheDay: Bool = true, leads: [Int] = [], minute: Int = 480, now: String = "2026-09-20T12:00:00Z", limit: Int = 30) -> [PlannedBirthdayReminder] {
    BirthdayNotificationPlanner.plan(items: items, options: BirthdayReminderOptions(onTheDay: onTheDay, leadDays: leads, minuteOfDay: minute),
                                     timezone: chicago, now: date(now), locale: us, limit: limit)
}
let emma = item("e", "Emma", next: "2026-09-25")

// On the day
let day = plan([emma])
check("one reminder on the day", String(day.count), "1")
check("fires at 8:00 local", local(day[0].fireDate), "2026-09-25 08:00")
check("title", day[0].title, "Emma's birthday")
check("body with age", day[0].body, "Emma turns 6 today.")
check("id", day[0].id, "birthday.e.0")
check("8:00 Chicago in September is 13:00 UTC", ISO8601DateFormatter().string(from: day[0].fireDate), "2026-09-25T13:00:00Z")

// Advance notice
let many = plan([emma], leads: [1, 7])
check("day, 1 and 7 before, soonest first", many.map { local($0.fireDate) }.joined(separator: " | "), "2026-09-18 08:00 | 2026-09-24 08:00 | 2026-09-25 08:00".replacingOccurrences(of: "2026-09-18 08:00 | ", with: ""))
check("week-before is already past so skipped", String(many.count), "2")
check("1 day before wording", many[0].title, "Emma's birthday is tomorrow")
check("1 day before body", many[0].body, "Emma turns 6 on Friday, Sep 25.")
let far = plan([item("f", "Noah", next: "2026-10-30")], leads: [14, 7, 3, 1])
check("all four leads plus the day", String(far.count), "5")
check("lead phrases", far.dropLast().map(\.title).joined(separator: " / "), "Noah's birthday is in 2 weeks / Noah's birthday is in 1 week / Noah's birthday is in 3 days / Noah's birthday is tomorrow")
check("lead-only (no on-the-day)", String(plan([item("f", "Noah", next: "2026-10-30")], onTheDay: false, leads: [7]).count), "1")

// Nothing to send
check("nothing selected", String(plan([emma], onTheDay: false, leads: []).count), "0")
check("zero and negative leads ignored", String(plan([emma], onTheDay: false, leads: [0, -3]).count), "0")
check("duplicate leads collapse", String(plan([item("f", "Noah", next: "2026-10-30")], onTheDay: false, leads: [7, 7, 7]).count), "1")

// Past times are skipped
check("on-the-day already passed today", String(plan([emma], now: "2026-09-25T15:00:00Z").count), "0")
check("still ahead earlier that day", String(plan([emma], now: "2026-09-25T12:00:00Z").count), "1")

// Time of day and zones
check("custom time 6:45 PM", local(plan([emma], minute: 18 * 60 + 45)[0].fireDate), "2026-09-25 18:45")
check("minutes are clamped", local(plan([emma], minute: 99999)[0].fireDate), "2026-09-25 23:59")
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let tokyoPlan = BirthdayNotificationPlanner.plan(items: [emma], options: BirthdayReminderOptions(onTheDay: true, leadDays: [], minuteOfDay: 480), timezone: tokyo, now: date("2026-09-20T12:00:00Z"), locale: us)
check("household time zone, not the device's", local(tokyoPlan[0].fireDate, tokyo), "2026-09-25 08:00")

// Daylight saving ends Nov 1: 8:00 must stay 8:00 local on both sides.
let nov = item("n", "Ava", next: "2026-11-02")
let dst = plan([nov], leads: [7])
check("week before the switch is still 8:00", local(dst[0].fireDate), "2026-10-26 08:00")
check("day after the switch is 8:00", local(dst[1].fireDate), "2026-11-02 08:00")

// Wording without a usable age
let noAge = plan([item("z", "Sam", next: "2026-09-25", age: 0)], leads: [1])
check("no age on the day", noAge[1].body, "It's Sam's birthday today.")
check("no age in advance", noAge[0].body, "Sam's birthday is on Friday, Sep 25.")

// Anniversaries
let anniversary = item("a", "Alex & Sam", next: "2026-09-25", age: 10, kind: .anniversary)
let annDay = plan([anniversary])
check("anniversary title", annDay[0].title, "Alex & Sam's anniversary")
check("anniversary body counts years", annDay[0].body, "10 years today.")
let annLead = plan([anniversary], onTheDay: false, leads: [1])
check("anniversary lead title", annLead[0].title, "Alex & Sam's anniversary is tomorrow")
check("anniversary lead body", annLead[0].body, "10 years on Friday, Sep 25.")
check("first anniversary is singular", plan([item("a", "Alex & Sam", next: "2026-09-25", age: 1, kind: .anniversary)])[0].body, "1 year today.")
check("anniversary with no usable year", plan([item("a", "Alex & Sam", next: "2026-09-25", age: 0, kind: .anniversary)])[0].body, "It's Alex & Sam's anniversary today.")
check("anniversary id matches the birthday scheme", annDay[0].id, "birthday.a.0")
check("birthdays and anniversaries mix in one plan", plan([emma, anniversary]).map(\.title).sorted().joined(separator: " | "), "Alex & Sam's anniversary | Emma's birthday")

// Robustness and limits
check("unparseable date is skipped", String(plan([item("q", "Bad", next: "not-a-date")]).count), "0")
let crowd = (1...40).map { item("b\($0)", "P\($0)", next: String(format: "2026-10-%02d", min($0, 28))) }
let capped = plan(crowd, leads: [1])
check("capped at the limit", String(capped.count), "30")
check("the soonest reminders are kept", String(capped.first!.fireDate <= capped.last!.fireDate), "true")
check("explicit smaller limit", String(plan(crowd, limit: 5).count), "5")

// Saved settings from an older app version must keep the person's choices.
let old = #"{"routinesEnabled":false,"choresEnabled":true,"sleepEnabled":true,"morningRoutineMinute":390,"afternoonRoutineMinute":900,"eveningRoutineMinute":1170,"choreMinute":1020,"bedtimeMinute":1200,"napCheckMinutes":60}"#
let migrated = try! JSONDecoder().decode(HomeHubNotificationSettings.self, from: Data(old.utf8))
check("old choice survives: routines off", String(migrated.routinesEnabled), "false")
check("old choice survives: morning time", String(migrated.morningRoutineMinute), "390")
check("old choice survives: nap check", String(migrated.napCheckMinutes), "60")
check("new birthday fields get defaults", "\(migrated.birthdaysEnabled) \(migrated.birthdayOnTheDay) \(migrated.birthdayLeadDays) \(migrated.birthdayMinute)", "true true [7] 480")
let roundTrip = try! JSONDecoder().decode(HomeHubNotificationSettings.self, from: JSONEncoder().encode(HomeHubNotificationSettings.defaults))
check("current settings round-trip", String(roundTrip == HomeHubNotificationSettings.defaults), "true")
let empty = try! JSONDecoder().decode(HomeHubNotificationSettings.self, from: Data("{}".utf8))
check("empty saved data becomes defaults", String(empty == HomeHubNotificationSettings.defaults), "true")

check("lead labels", [1, 3, 7, 14].map(BirthdayNotificationPlanner.leadLabel).joined(separator: ", "), "1 Day Before, 3 Days Before, 1 Week Before, 2 Weeks Before")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
