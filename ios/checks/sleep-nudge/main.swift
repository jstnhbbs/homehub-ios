import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
let iso = ISO8601DateFormatter()
iso.timeZone = calendar.timeZone
func date(_ text: String) -> Date { iso.date(from: text)! }
func local(_ date: Date) -> String {
    let f = DateFormatter(); f.timeZone = calendar.timeZone; f.dateFormat = "MM-dd HH:mm"; return f.string(from: date)
}
func log(_ id: String, kind: String = "night", from: String, to: String? = nil) -> NapLog {
    let end = to.map { #""\#(iso.string(from: date($0)))""# } ?? "null"
    let json = #"{"id":"\#(id)","profileId":"child","kind":"\#(kind)","localDate":"2026-10-15","startedAt":"\#(iso.string(from: date(from)))","endedAt":\#(end),"notes":null}"#
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    return try! decoder.decode(NapLog.self, from: Data(json.utf8))
}
func plan(_ logs: [NapLog], minute: Int = 8 * 60, now: String) -> [SleepNudge] {
    SleepNudgePlanner.nudges(logs: logs, minuteOfDay: minute, calendar: calendar, now: date(now))
}

let evening = log("a", from: "2026-10-15T20:15:00-05:00")
check("a night sleep gets the next 8 a.m.", plan([evening], now: "2026-10-15T20:30:00-05:00").map { local($0.fireDate) }.joined(), "10-16 08:00")
check("the id names the sleep", plan([evening], now: "2026-10-15T20:30:00-05:00").first?.id ?? "none", "sleep.night.a")
check("it remembers when the sleep began", plan([evening], now: "2026-10-15T20:30:00-05:00").first.map { local($0.startedAt) } ?? "none", "10-15 20:15")
check("a nap gets none (it has an End button on its Live Activity)", String(plan([log("n", kind: "nap", from: "2026-10-15T13:00:00-05:00")], now: "2026-10-15T13:30:00-05:00").count), "0")
check("an ended night gets none", String(plan([log("e", from: "2026-10-15T20:00:00-05:00", to: "2026-10-16T06:30:00-05:00")], now: "2026-10-16T07:00:00-05:00").count), "0")
check("after the reminder time it plans the next morning", plan([evening], now: "2026-10-16T09:00:00-05:00").map { local($0.fireDate) }.joined(), "10-17 08:00")
check("before the reminder time the same morning is planned", plan([evening], now: "2026-10-16T05:00:00-05:00").map { local($0.fireDate) }.joined(), "10-16 08:00")
check("a sleep begun at 6 a.m. isn't reminded at 8 (too short)", plan([log("s", from: "2026-10-16T06:00:00-05:00")], now: "2026-10-16T06:10:00-05:00").map { local($0.fireDate) }.joined(), "10-17 08:00")
check("a sleep begun at 3 a.m. is reminded at 8 (five hours)", plan([log("s", from: "2026-10-16T03:00:00-05:00")], now: "2026-10-16T03:10:00-05:00").map { local($0.fireDate) }.joined(), "10-16 08:00")
check("a custom time is used", plan([evening], minute: 7 * 60 + 30, now: "2026-10-15T20:30:00-05:00").map { local($0.fireDate) }.joined(), "10-16 07:30")
check("two sleeping children are both planned, soonest first", plan([evening, log("b", from: "2026-10-15T19:00:00-05:00")], now: "2026-10-15T21:00:00-05:00").map(\.sleepId).joined(separator: ","), "a,b")
check("out of range minutes are held to the day", plan([evening], minute: 5000, now: "2026-10-15T20:30:00-05:00").map { local($0.fireDate) }.joined(), "10-16 23:59")
check("a reminder exactly at the time is kept", plan([evening], now: "2026-10-16T08:00:00-05:00").map { local($0.fireDate) }.joined(), "10-16 08:00")
// Daylight saving ends 2026-11-01 in the US: the clock time still holds.
check("the reminder time holds across the clock change", plan([log("d", from: "2026-10-31T20:00:00-05:00")], now: "2026-10-31T20:30:00-05:00").map { local($0.fireDate) }.joined(), "11-01 08:00")

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall sleep nudge checks passed")
