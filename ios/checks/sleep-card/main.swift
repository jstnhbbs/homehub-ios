import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let utc = TimeZone(identifier: "UTC")!
// 2026-10-07 12:00 UTC.
let now = Date(timeIntervalSince1970: 1_791_374_400)
func at(_ hour: Int, _ minutes: Int = 0) -> Date { now.addingTimeInterval(TimeInterval((hour - 12) * 3600 + minutes * 60)) }
let iso = ISO8601DateFormatter()

func profile(_ id: String, _ name: String) -> Profile {
    let json = ##"{"id":"\##(id)","householdId":"h","profileType":"child","name":"\##(name)","color":"#d87861","avatar":"sparkles","sortOrder":0}"##
    return try! JSONDecoder().decode(Profile.self, from: Data(json.utf8))
}
func log(_ id: String, _ child: String, kind: String = "nap", from: Date, to: Date?) -> NapLog {
    let end = to.map { #""\#(iso.string(from: $0))""# } ?? "null"
    let json = #"{"id":"\#(id)","profileId":"\#(child)","kind":"\#(kind)","localDate":"2026-10-07","startedAt":"\#(iso.string(from: from))","endedAt":\#(end),"notes":null}"#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try! decoder.decode(NapLog.self, from: Data(json.utf8))
}
func summary(_ children: [Profile], _ logs: [NapLog]) -> SleepCardSummary {
    SleepCardSummary(children: children, logs: logs, localDate: "2026-10-07", timezone: utc, now: now)
}

let maya = profile("maya", "Maya Rivera")
let nova = profile("nova", "Nova")

// MARK: Small

check("no children", summary([], []).headline, "No children")
check("no children caption", summary([], []).caption, "Add a child profile")
check("nothing logged", summary([maya], []).headline, "No sleep")
check("nothing logged caption", summary([maya], []).caption, "logged today")

let awake = summary([maya, nova], [log("a", "maya", from: at(9), to: at(10)), log("b", "nova", from: at(9), to: at(11))])
check("the child awake longest leads", awake.lead?.profile.id ?? "nil", "maya")
check("awake caption uses the first name", awake.caption, "Maya awake")
check("awake for two hours", awake.headline, "2h")

let napping = summary([maya, nova], [log("a", "maya", from: at(9), to: at(10)), log("b", "nova", from: at(11, 10), to: nil)])
check("someone asleep leads, even if another has been awake longer", napping.lead?.profile.id ?? "nil", "nova")
check("napping caption", napping.caption, "Nova napping")
check("how long", napping.headline, "50m")
check("asleep line", napping.line, "1 asleep now")
check("awake line", awake.line, "Everyone awake")
check("no sleep line", summary([maya], []).line, "No sleep logged today")

// MARK: the log

let day = summary([maya], [log("n2", "maya", from: at(13), to: nil), log("n1", "maya", from: at(9, 10), to: at(10, 20)), log("night", "maya", kind: "night", from: at(0), to: at(7))])
check("in order, with what each was", day.entries(for: maya).map(\.title).joined(separator: ","), "Night,Nap,Nap")
check("a finished sleep has a range", day.entries(for: maya)[1].range.replacingOccurrences(of: "\u{202F}", with: " "), "9:10 AM – 10:20 AM")
check("a running one says since", day.entries(for: maya)[2].range.hasPrefix("since ") ? "since" : day.entries(for: maya)[2].range, "since")
check("how long a nap was", day.entries(for: maya)[1].duration, "1h 10m")

// MARK: short wording for narrow rows

let shortAwake = summary([maya, nova], [log("a", "maya", from: at(9), to: at(10)), log("b", "nova", from: at(11, 10), to: nil)])
check("awake in a few words", shortAwake.shortStatusText(for: maya), "Awake 2h")
check("asleep in a few words", shortAwake.shortStatusText(for: nova), "Zzz 50m")
check("asleep, spoken in full", shortAwake.spokenStatusText(for: nova), "Asleep 50m")
check("awake, spoken in full", shortAwake.spokenStatusText(for: maya), "Awake 2h")
check("nothing logged, spoken in full", summary([maya], []).spokenStatusText(for: maya), "No sleep logged today")
check("nothing logged in a few words", summary([maya], []).shortStatusText(for: maya), "No sleep yet")
check("the short wording is shorter than the long", shortAwake.shortStatusText(for: nova).count < "Nap · asleep 50m".count ? "shorter" : "not shorter", "shorter")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
