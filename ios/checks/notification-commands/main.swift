import Foundation

var failures = 0
func check(_ label: String, _ ok: Bool) {
    if ok { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

let chore = NotificationCommands.choreInfo(choreId: "c1", periodKey: "2026-10-08", title: "Take the bins out")
let nap = NotificationCommands.napInfo(napId: "n1", name: "Ada")
let tap = "com.apple.UNNotificationDefaultActionIdentifier"
let dismiss = "com.apple.UNNotificationDismissActionIdentifier"

check("Done on a chore reminder completes that chore for that period",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: chore)
        == .completeChore(choreId: "c1", periodKey: "2026-10-08", title: "Take the bins out"))
check("End Nap on a nap check ends that nap",
      NotificationCommands.command(actionIdentifier: NotificationCommands.endNapAction, userInfo: nap)
        == .endNap(napId: "n1", name: "Ada"))
check("tapping the notification itself does nothing here",
      NotificationCommands.command(actionIdentifier: tap, userInfo: chore) == nil)
check("dismissing it does nothing", NotificationCommands.command(actionIdentifier: dismiss, userInfo: nap) == nil)
check("Done on a nap check is not a thing",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: nap) == nil)
check("End Nap on a chore reminder is not a thing",
      NotificationCommands.command(actionIdentifier: NotificationCommands.endNapAction, userInfo: chore) == nil)
check("a notification from before it had buttons is ignored",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: [:]) == nil)
check("a chore with no period is ignored, not guessed",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: ["kind": "chore", "choreId": "c1"]) == nil)
check("a chore with an empty id is ignored",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: ["kind": "chore", "choreId": "", "periodKey": "x"]) == nil)
check("a nap with no id is ignored",
      NotificationCommands.command(actionIdentifier: NotificationCommands.endNapAction, userInfo: ["kind": "nap"]) == nil)
check("values of the wrong type are ignored",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: ["kind": "chore", "choreId": 5, "periodKey": "x"]) == nil)
check("a missing title falls back to a plain word",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: ["kind": "chore", "choreId": "c1", "periodKey": "x"])
        == .completeChore(choreId: "c1", periodKey: "x", title: "Chore"))
check("userInfo from a remote-style push (top-level keys, any hashable) works",
      NotificationCommands.command(actionIdentifier: NotificationCommands.doneAction, userInfo: ["aps": ["alert": "x"], "kind": "chore", "choreId": "c9", "periodKey": "once", "title": "Fix gate"] as [AnyHashable: Any])
        == .completeChore(choreId: "c9", periodKey: "once", title: "Fix gate"))
check("the failure message names the chore", NotificationCommands.failureMessage(for: .completeChore(choreId: "c", periodKey: "p", title: "Bins")).body.contains("Bins"))
check("the failure message names the child", NotificationCommands.failureMessage(for: .endNap(napId: "n", name: "Ada")).body.contains("Ada"))

check("a routine reminder opens Routines", NotificationCommands.destination(forNotificationId: "routine.morning.everyone.Brush teeth") == "routines")
check("a timed chore reminder opens Chores", NotificationCommands.destination(forNotificationId: "chore.abc.2026-10-07") == "chores")
check("the evening chore check-in opens Chores", NotificationCommands.destination(forNotificationId: "chores.today") == "chores")
check("bedtime and nap checks open Sleep", NotificationCommands.destination(forNotificationId: "sleep.bedtime") == "sleep" && NotificationCommands.destination(forNotificationId: "sleep.nap.n1") == "sleep")
check("a birthday reminder opens Celebrations", NotificationCommands.destination(forNotificationId: "birthday.b1.0") == "birthdays")
check("an unknown id opens nothing", NotificationCommands.destination(forNotificationId: "homehub.action.failed.x") == nil)
check("a name that merely starts with a page word opens nothing", NotificationCommands.destination(forNotificationId: "choresx.1") == nil)
check("a tap reads the destination", NotificationCommands.destination(userInfo: ["destination": "chores"]) == "chores")
check("an unknown destination is ignored", NotificationCommands.destination(userInfo: ["destination": "settings"]) == nil)
check("no destination, nothing to open", NotificationCommands.destination(userInfo: ["kind": "chore"]) == nil)

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall notification command checks passed")
