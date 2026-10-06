import Foundation

var failures = 0
func check(_ label: String, _ rawActual: String, _ expected: String) {
    // Current iOS writes a narrow no-break space before AM/PM; it reads as an ordinary space.
    let actual = rawActual.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
// Monday 5 October 2026, 15:30 in Chicago.
let date = ISO8601DateFormatter().date(from: "2026-10-05T20:30:00Z")!
let us = Locale(identifier: "en_US")
let uk = Locale(identifier: "en_GB")
let de = Locale(identifier: "de_DE")

// MARK: What a US household sees must not change

check("US weekday and date", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "EEEE, MMMM d", locale: us), "Monday, October 5")
check("US short weekday and date", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "EEE, MMM d", locale: us), "Mon, Oct 5")
check("US month and day", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "MMM d", locale: us), "Oct 5")
check("US month day year", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "MMM d, yyyy", locale: us), "Oct 5, 2026")
check("US weekday only", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "EEEE", locale: us), "Monday")
check("US header date", DateHelpers.headerDateLabel(timezone: chicago, date: date, locale: us), "Monday, October 5")
check("US month title", CalendarHelpers.monthTitle(date, timezone: chicago, locale: us), "October 2026")
check("US week title", CalendarHelpers.weekTitle(start: date, end: date.addingTimeInterval(6 * 86_400), timezone: chicago, locale: us), "Oct 5 – Oct 11, 2026")
check("US hour label, morning", CalendarHelpers.hourLabel(9, selectedDate: "2026-10-05", timezone: chicago, locale: us), "9 AM")
check("US hour label, afternoon", CalendarHelpers.hourLabel(15, selectedDate: "2026-10-05", timezone: chicago, locale: us), "3 PM")

// MARK: Other places read the way they expect

check("UK puts the day first", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "EEE, MMM d", locale: uk), "Mon 5 Oct")
check("UK hour label is 24-hour", CalendarHelpers.hourLabel(15, selectedDate: "2026-10-05", timezone: chicago, locale: uk), "15")
check("German weekday is in German", DateHelpers.formatLocalDate("2026-10-05", timezone: chicago, pattern: "EEEE", locale: de), "Montag")
check("German month title", CalendarHelpers.monthTitle(date, timezone: chicago, locale: de), "Oktober 2026")

// MARK: The time zone is the household's, not the device's

let tokyo = TimeZone(identifier: "Asia/Tokyo")!
check("a late evening Chicago time is already tomorrow in Tokyo", DateHelpers.formatLocalDate("2026-10-06", timezone: tokyo, pattern: "EEEE", locale: us), "Tuesday")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
