import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// Wording per kind
check("birthday noun", CelebrationKind.birthday.noun, "birthday")
check("anniversary noun", CelebrationKind.anniversary.noun, "anniversary")
check("capitalized", CelebrationKind.anniversary.capitalizedNoun, "Anniversary")
check("birthday icon", CelebrationKind.birthday.systemImage, "gift.fill")
check("anniversary icon", CelebrationKind.anniversary.systemImage, "heart.fill")
check("birthday detail", String(describing: CelebrationKind.birthday.ageDetail(6)), "Optional(\"turns 6\")")
check("anniversary detail", String(describing: CelebrationKind.anniversary.ageDetail(10)), "Optional(\"10 years\")")
check("one year", String(describing: CelebrationKind.anniversary.ageDetail(1)), "Optional(\"1 year\")")
check("no detail for zero", String(describing: CelebrationKind.birthday.ageDetail(0)), "nil")
check("no detail for absurd numbers", String(describing: CelebrationKind.anniversary.ageDetail(2026)), "nil")

// The module's name
check("no anniversaries", CelebrationNaming.title(hasAnniversaries: false), "Birthdays")
check("with anniversaries", CelebrationNaming.title(hasAnniversaries: true), "Celebrations")
check("reminders, birthdays only", CelebrationNaming.remindersTitle(hasAnniversaries: false), "Birthday Reminders")
check("reminders, with anniversaries", CelebrationNaming.remindersTitle(hasAnniversaries: true), "Celebration Reminders")
let defaults = UserDefaults(suiteName: "beacon.celebration.checks.\(UUID().uuidString)")!
check("starts as birthdays", String(CelebrationNaming.hasAnniversaries(defaults: defaults)), "false")
CelebrationNaming.setHasAnniversaries(true, defaults: defaults)
check("remembered", String(CelebrationNaming.hasAnniversaries(defaults: defaults)), "true")
CelebrationNaming.setHasAnniversaries(false, defaults: defaults)
check("can be turned back off", String(CelebrationNaming.hasAnniversaries(defaults: defaults)), "false")

// Entries from the server, with and without a kind
func decode(_ json: String) -> BirthdayItem {
    try! JSONDecoder().decode(BirthdayItem.self, from: Data(json.utf8))
}
let base = ##""id":"x","source":"family","profileId":null,"name":"Alex & Sam","birthDate":"2016-09-25","color":"#4f7c6d","avatar":null,"notes":null,"giftIdeas":null,"notifyDaysBefore":7,"nextDate":"2026-09-25","daysUntil":0,"upcomingAge":10"##
check("older server: no kind means birthday", decode("{\(base)}").kind.rawValue, "birthday")
check("kind: anniversary", decode(#"{\#(base),"kind":"anniversary"}"#).kind.rawValue, "anniversary")
check("kind: birthday", decode(#"{\#(base),"kind":"birthday"}"#).kind.rawValue, "birthday")
let roundTrip = try! JSONDecoder().decode(BirthdayItem.self, from: JSONEncoder().encode(decode(#"{\#(base),"kind":"anniversary"}"#)))
check("survives being saved and reloaded", roundTrip.kind.rawValue, "anniversary")

// What the app sends
func encoded(_ input: BirthdayWriteInput) -> String {
    let data = try! JSONEncoder().encode(input)
    return String(data: data, encoding: .utf8)!
}
check("anniversary is sent", String(encoded(BirthdayWriteInput(name: "A", birthDate: "2016-09-25", kind: .anniversary)).contains("\"kind\":\"anniversary\"")), "true")
check("no kind is left out, so old behavior stays", String(encoded(BirthdayWriteInput(name: "A", birthDate: "2016-09-25", kind: nil)).contains("kind")), "false")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
