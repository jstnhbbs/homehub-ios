import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func note(_ id: String, body: String = "body", trigger: String = "2026-10-4 18:0 America/Chicago") -> PlannedNotification {
    PlannedNotification(id: id, title: "Title", body: body, thread: "homehub", trigger: trigger)
}
func describe(_ c: NotificationDiff.Changes) -> String {
    "remove=\(c.remove.joined(separator: ",")) add=\(c.add.joined(separator: ","))"
}

check("nothing scheduled, nothing wanted", describe(NotificationDiff.changes(existing: [], desired: [])), "remove= add=")
check("everything already scheduled as wanted: nothing to do",
      describe(NotificationDiff.changes(existing: [note("a"), note("b")], desired: [note("a"), note("b")])), "remove= add=")
check("order doesn't matter",
      describe(NotificationDiff.changes(existing: [note("b"), note("a")], desired: [note("a"), note("b")])), "remove= add=")
check("a new reminder is added",
      describe(NotificationDiff.changes(existing: [note("a")], desired: [note("a"), note("b")])), "remove= add=b")
check("one that is no longer wanted is removed",
      describe(NotificationDiff.changes(existing: [note("a"), note("b")], desired: [note("a")])), "remove=b add=")
check("a changed message is replaced, not removed first",
      describe(NotificationDiff.changes(existing: [note("a", body: "3 steps left")], desired: [note("a", body: "2 steps left")])), "remove= add=a")
check("a changed time is replaced",
      describe(NotificationDiff.changes(existing: [note("a")], desired: [note("a", trigger: "2026-10-4 19:0 America/Chicago")])), "remove= add=a")
check("a reminder that gains its buttons is replaced",
      describe(NotificationDiff.changes(existing: [note("a")], desired: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", category: "beacon.chore", trigger: "2026-10-4 18:0 America/Chicago")])), "remove= add=a")
check("the same buttons are left alone",
      describe(NotificationDiff.changes(
        existing: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", category: "beacon.chore", trigger: "t")],
        desired: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", category: "beacon.chore", trigger: "t")])), "remove= add=")
check("a reminder that gains a page to open is replaced",
      describe(NotificationDiff.changes(existing: [note("a")], desired: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", destination: "chores", trigger: "2026-10-4 18:0 America/Chicago")])), "remove= add=a")
check("the same page is left alone",
      describe(NotificationDiff.changes(
        existing: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", destination: "chores", trigger: "t")],
        desired: [PlannedNotification(id: "a", title: "Title", body: "body", thread: "homehub", destination: "chores", trigger: "t")])), "remove= add=")
check("a mix",
      describe(NotificationDiff.changes(
        existing: [note("keep"), note("gone"), note("edit", body: "old")],
        desired: [note("keep"), note("edit", body: "new"), note("fresh")])),
      "remove=gone add=edit,fresh")
check("all scheduled, none wanted",
      describe(NotificationDiff.changes(existing: [note("a"), note("b")], desired: [])), "remove=a,b add=")
check("none scheduled, all wanted, in the order given",
      describe(NotificationDiff.changes(existing: [], desired: [note("z"), note("a")])), "remove= add=z,a")
check("the same id wanted twice schedules the later one once",
      describe(NotificationDiff.changes(existing: [note("a", body: "later")], desired: [note("a", body: "earlier"), note("a", body: "later")])), "remove= add=")
check("a duplicate scheduled id is removed once when unwanted",
      describe(NotificationDiff.changes(existing: [note("a"), note("a")], desired: [])), "remove=a add=")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
