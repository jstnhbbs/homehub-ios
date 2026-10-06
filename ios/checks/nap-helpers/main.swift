import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
let auckland = TimeZone(identifier: "Pacific/Auckland")!
let tokyo = TimeZone(identifier: "Asia/Tokyo")!

func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

// MARK: DateHelpers, now cached

check("local date follows the household zone, not the device", DateHelpers.localDateIn(timezone: tokyo, date: date("2026-10-04T20:00:00Z")), "2026-10-05")
check("and the same instant is still the 4th in Chicago", DateHelpers.localDateIn(timezone: chicago, date: date("2026-10-04T20:00:00Z")), "2026-10-04")
check("repeat calls agree", DateHelpers.localDateIn(timezone: tokyo, date: date("2026-10-04T20:00:00Z")), "2026-10-05")

let midnight = DateHelpers.dateFromLocalDate("2026-10-04", timezone: chicago)!
check("local midnight in Chicago is 05:00Z", ISO8601DateFormatter().string(from: midnight), "2026-10-04T05:00:00Z")
check("a cached zone does not leak into another", ISO8601DateFormatter().string(from: DateHelpers.dateFromLocalDate("2026-10-04", timezone: tokyo)!), "2026-10-03T15:00:00Z")

check("pattern formatting", DateHelpers.formatLocalDate("2026-10-04", timezone: chicago, pattern: "EEE, MMM d"), "Sun, Oct 4")
check("same pattern, other zone, same local date", DateHelpers.formatLocalDate("2026-10-04", timezone: tokyo, pattern: "EEE, MMM d"), "Sun, Oct 4")
check("weekday", DateHelpers.weekdayShort(date("2026-10-04T20:00:00Z"), timezone: tokyo), "Mon")
check("weekday, other zone", DateHelpers.weekdayShort(date("2026-10-04T20:00:00Z"), timezone: chicago), "Sun")
check("day number", DateHelpers.dayNumber(date("2026-10-04T20:00:00Z"), timezone: tokyo), "5")
check("header label", DateHelpers.headerDateLabel(timezone: chicago, date: date("2026-10-04T20:00:00Z")), "Sunday, October 4")
check("times differ between zones", String(DateHelpers.timeString(date("2026-10-04T20:00:00Z"), timezone: chicago) == DateHelpers.timeString(date("2026-10-04T20:00:00Z"), timezone: tokyo)), "false")

// MARK: Sleep minutes across a day boundary, including a day that is not 24 hours long

// Auckland falls back on 2026-04-05, so that local day is 25 hours long.
let sleepStart = date("2026-04-05T10:00:00Z") // 22:00 NZST on the 5th
let sleepEnd = date("2026-04-05T13:00:00Z")   // 01:00 NZST on the 6th
check("late-evening sleep counts only its part of the 25-hour day", String(NapHelpers.overlapMinutes(startedAt: sleepStart, endedAt: sleepEnd, localDate: "2026-04-05", timezone: auckland)), "120")
check("and the rest belongs to the next day", String(NapHelpers.overlapMinutes(startedAt: sleepStart, endedAt: sleepEnd, localDate: "2026-04-06", timezone: auckland)), "60")

let night = NapLogSample.make(id: "n", kind: "night", start: sleepStart, end: sleepEnd)
check("a night touches both days it spans (first)", String(NapHelpers.sleepOverlapsLocalDate(night, localDate: "2026-04-05", timezone: auckland)), "true")
check("a night touches both days it spans (second)", String(NapHelpers.sleepOverlapsLocalDate(night, localDate: "2026-04-06", timezone: auckland)), "true")
check("but not the day before", String(NapHelpers.sleepOverlapsLocalDate(night, localDate: "2026-04-04", timezone: auckland)), "false")
check("or the day after", String(NapHelpers.sleepOverlapsLocalDate(night, localDate: "2026-04-07", timezone: auckland)), "false")

check("minutes into the local day", String(NapTimelineHelpers.minutesOnLocalDate(sleepStart, localDate: "2026-04-05", timezone: auckland) ?? -1), "1320")
check("a different local day gives nothing", String(NapTimelineHelpers.minutesOnLocalDate(sleepStart, localDate: "2026-04-06", timezone: auckland) ?? -1), "-1")

// MARK: NapsPayload.apply and remove

let json = """
{"localDate":"2026-10-04","weekDates":["2026-10-04"],"childProfiles":[],
 "naps":[{"id":"a","profileId":"p","kind":"nap","localDate":"2026-10-04","startedAt":"2026-10-04T15:00:00Z","endedAt":null}],
 "weekLogs":[{"id":"a","profileId":"p","kind":"nap","localDate":"2026-10-04","startedAt":"2026-10-04T15:00:00Z","endedAt":null},
             {"id":"z","profileId":"p","kind":"night","localDate":"2026-10-04","startedAt":"2026-10-04T02:00:00Z","endedAt":"2026-10-04T12:00:00Z"}]}
"""
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
var payload = try! decoder.decode(NapsPayload.self, from: Data(json.utf8))

payload.apply(NapLogSample.make(id: "a", kind: "nap", start: date("2026-10-04T15:00:00Z"), end: date("2026-10-04T16:00:00Z")))
check("an ended nap replaces the running one in the week", String(payload.weekLogs.first { $0.id == "a" }?.endedAt != nil), "true")
check("and in today's list", String(payload.naps.first { $0.id == "a" }?.endedAt != nil), "true")
check("without duplicating it", String(payload.weekLogs.filter { $0.id == "a" }.count), "1")

payload.apply(NapLogSample.make(id: "b", kind: "nap", start: date("2026-10-04T13:00:00Z"), end: date("2026-10-04T14:00:00Z")))
check("a new nap joins the week in start order", payload.weekLogs.map(\.id).joined(separator: ","), "z,b,a")
check("a new finished nap also joins today's naps", payload.naps.map(\.id).joined(separator: ","), "b,a")

payload.apply(NapLogSample.make(id: "c", kind: "night", start: date("2026-10-04T20:00:00Z"), end: date("2026-10-04T21:00:00Z")))
check("a finished night is not added to today's naps", String(payload.naps.contains { $0.id == "c" }), "false")
check("but it is in the week", String(payload.weekLogs.contains { $0.id == "c" }), "true")

payload.apply(NapLogSample.make(id: "d", kind: "night", start: date("2026-10-04T22:00:00Z"), end: nil))
check("a night still running is added to the running list", String(payload.naps.contains { $0.id == "d" }), "true")

payload.remove(id: "b")
check("remove drops it from the week", String(payload.weekLogs.contains { $0.id == "b" }), "false")
check("and from today's naps", String(payload.naps.contains { $0.id == "b" }), "false")

// MARK: The timeline reads in the person's own clock

let usLocale = Locale(identifier: "en_US")
let germanLocale = Locale(identifier: "de_DE")
check("US axis labels are as they always were", NapTimelineHelpers.axisHours.map { NapTimelineHelpers.compactHourLabel($0, locale: usLocale) }.joined(separator: " "), "5a 8a 11a 2p 5p 8p 11p")
check("US heatmap ranges are as they always were", NapTimelineHelpers.heatmapBlocks.map { NapTimelineHelpers.rangeLabel(startHour: $0.startHour, endHour: $0.endHour, locale: usLocale) }.joined(separator: " "), "5–8a 8–11a 11–2p 2–5p 5–8p 8–11p")
check("a 24-hour region gets 24-hour axis labels", NapTimelineHelpers.axisHours.map { NapTimelineHelpers.compactHourLabel($0, locale: germanLocale) }.joined(separator: " "), "5 8 11 14 17 20 23")
check("and 24-hour ranges", NapTimelineHelpers.rangeLabel(startHour: 11, endHour: 14, locale: germanLocale), "11–14")
check("US uses AM/PM", String(NapTimelineHelpers.uses24HourClock(locale: usLocale)), "false")
check("Germany does not", String(NapTimelineHelpers.uses24HourClock(locale: germanLocale)), "true")
check("midday is 12p, not 0p", NapTimelineHelpers.compactHourLabel(12, locale: usLocale), "12p")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")

enum NapLogSample {
    /// NapLog only decodes, so the samples go through JSON.
    static func make(id: String, kind: String, start: Date, end: Date?) -> NapLog {
        let formatter = ISO8601DateFormatter()
        let endValue = end.map { "\"\(formatter.string(from: $0))\"" } ?? "null"
        let body = """
        {"id":"\(id)","profileId":"p","kind":"\(kind)","localDate":"2026-10-04","startedAt":"\(formatter.string(from: start))","endedAt":\(endValue)}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(NapLog.self, from: Data(body.utf8))
    }
}
