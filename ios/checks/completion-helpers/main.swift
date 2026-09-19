import Foundation

// Weekday assertions assume an English system locale ("Tue", "Fri").

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let chicago = TimeZone(identifier: "America/Chicago")!
func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
let now = date("2026-09-18T20:00:00Z")           // 3:00 PM in Chicago
let sameDay = date("2026-09-18T15:42:00Z")       // 10:42 AM in Chicago
let earlier = date("2026-09-15T20:42:00Z")       // a few days before

check("nothing known", String(describing: CompletionHelpers.caption(name: nil, completedAt: nil, timezone: chicago, now: now)), "nil")
check("blank name and no time", String(describing: CompletionHelpers.caption(name: "  ", completedAt: nil, timezone: chicago, now: now)), "nil")
check("name only", CompletionHelpers.caption(name: "Alex", completedAt: nil, timezone: chicago, now: now)!, "Alex")

let same = CompletionHelpers.caption(name: "Alex", completedAt: sameDay, timezone: chicago, now: now)!
check("same day has name, dot, and a time", String(same.hasPrefix("Alex · ") && same.count > "Alex · ".count), "true")
check("same day shows no weekday", String(same.contains("Tue") || same.contains("Wed") || same.contains("Fri")), "false")

let past = CompletionHelpers.caption(name: "Alex", completedAt: earlier, timezone: chicago, now: now)!
check("earlier day includes a weekday", String(past.contains("Tue")), "true")

let timeOnly = CompletionHelpers.caption(name: nil, completedAt: sameDay, timezone: chicago, now: now)!
check("time only has no name or dot", String(!timeOnly.contains("·") && !timeOnly.isEmpty), "true")

// The same instant lands on different local days in different zones.
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let lateNightChicago = date("2026-09-19T03:30:00Z")   // Sep 18 10:30 PM Chicago, Sep 19 12:30 PM Tokyo
let nowChicago = date("2026-09-19T04:00:00Z")          // Sep 18 11:00 PM Chicago
let nowTokyo = date("2026-09-19T04:00:00Z")            // Sep 19 1:00 PM Tokyo
check("same local day in Chicago", String(!CompletionHelpers.caption(name: "A", completedAt: lateNightChicago, timezone: chicago, now: nowChicago)!.contains("Fri")), "true")
check("same local day in Tokyo", String(!CompletionHelpers.caption(name: "A", completedAt: lateNightChicago, timezone: tokyo, now: nowTokyo)!.contains("Sat")), "true")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
