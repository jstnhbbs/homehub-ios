import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

check("3 is a milestone", String(StreakHelpers.isMilestone(3)), "true")
check("7 is a milestone", String(StreakHelpers.isMilestone(7)), "true")
check("4 is not", String(StreakHelpers.isMilestone(4)), "false")
check("0 is not", String(StreakHelpers.isMilestone(0)), "false")
check("365 is a milestone", String(StreakHelpers.isMilestone(365)), "true")
check("label", StreakHelpers.label(7), "7-day streak")
check("message", StreakHelpers.celebrationMessage(name: "Sam", days: 14), "Sam hit a 14-day streak!")

let defaults = UserDefaults(suiteName: "beacon.streak.checks.\(UUID().uuidString)")!
check("not celebrated at first", String(StreakHelpers.hasCelebrated(profileKey: "kid1", localDate: "2026-09-18", defaults: defaults)), "false")
StreakHelpers.markCelebrated(profileKey: "kid1", localDate: "2026-09-18", defaults: defaults)
check("celebrated once today", String(StreakHelpers.hasCelebrated(profileKey: "kid1", localDate: "2026-09-18", defaults: defaults)), "true")
check("another child is independent", String(StreakHelpers.hasCelebrated(profileKey: "kid2", localDate: "2026-09-18", defaults: defaults)), "false")
check("celebrates again on a later day", String(StreakHelpers.hasCelebrated(profileKey: "kid1", localDate: "2026-09-25", defaults: defaults)), "false")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
