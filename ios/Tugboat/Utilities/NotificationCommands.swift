import Foundation

/// What a button on a notification asks the app to do. Foundation only, so the decoding can be
/// checked from the command line (`ios/checks/notification-commands`).
enum NotificationCommand: Equatable, Sendable {
    /// Mark a chore done for the period the reminder was about.
    case completeChore(choreId: String, periodKey: String, title: String)
    /// End a running sleep (the "still asleep" reminder's Wake Up button).
    case endSleep(sleepId: String, name: String)
}

enum NotificationCommands {
    // Categories say which buttons a notification gets; actions say which button was pressed.
    static let choreCategory = "tugboat.chore"
    static let sleepCategory = "tugboat.sleep"
    static let doneAction = "tugboat.done"
    static let wakeUpAction = "tugboat.wakeUp"

    /// What a chore reminder carries so its Done button knows which chore and which period.
    static func choreInfo(choreId: String, periodKey: String, title: String) -> [String: String] {
        ["kind": "chore", "choreId": choreId, "periodKey": periodKey, "title": title]
    }

    /// What a "still asleep" reminder carries so its Wake Up button knows which sleep.
    static func sleepInfo(sleepId: String, name: String) -> [String: String] {
        ["kind": "sleep", "sleepId": sleepId, "name": name]
    }

    /// The `userInfo` key that names the page a notification belongs to.
    static let destinationKey = "destination"

    /// Pages a tap may open: the raw values of the matching `HubDestination`s. Anything else in a
    /// notification is ignored, so a stale or odd value can't send the app somewhere unexpected.
    static let openableDestinations: Set<String> = ["routines", "chores", "sleep", "birthdays"]

    /// The page a reminder belongs to, from the id the planner gave it (routine.*, chore.*,
    /// chores.today, sleep.*, birthday.*), or nil for one that belongs to no page.
    static func destination(forNotificationId id: String) -> String? {
        let prefix = id.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
        switch prefix {
        case "routine": return "routines"
        case "chore", "chores": return "chores"
        case "sleep": return "sleep"
        case "birthday": return "birthdays"
        default: return nil
        }
    }

    /// The page to open when the notification itself is tapped, if it names one we know.
    static func destination(userInfo: [AnyHashable: Any]) -> String? {
        guard let value = userInfo[destinationKey] as? String, openableDestinations.contains(value) else { return nil }
        return value
    }

    /// The command a pressed button stands for, or nil when it is not one of ours (tapping the
    /// notification itself, dismissing it, or a notification from before it had buttons).
    static func command(actionIdentifier: String, userInfo: [AnyHashable: Any]) -> NotificationCommand? {
        func text(_ key: String) -> String? {
            guard let value = userInfo[key] as? String, !value.isEmpty else { return nil }
            return value
        }
        switch (actionIdentifier, text("kind")) {
        case (doneAction, "chore"):
            guard let choreId = text("choreId"), let periodKey = text("periodKey") else { return nil }
            return .completeChore(choreId: choreId, periodKey: periodKey, title: text("title") ?? "Chore")
        case (wakeUpAction, "sleep"):
            guard let sleepId = text("sleepId") else { return nil }
            return .endSleep(sleepId: sleepId, name: text("name") ?? "Sleep")
        default:
            return nil
        }
    }

    /// What to tell the person when a button could not do its job (no connection, signed out), so
    /// a chore never looks done when it is not.
    static func failureMessage(for command: NotificationCommand) -> (title: String, body: String) {
        switch command {
        case .completeChore(_, _, let title):
            return ("Couldn't mark it done", "\(title) wasn't marked done. Open Tugboat to try again.")
        case .endSleep(_, let name):
            return ("Couldn't end the sleep", "\(name)'s sleep wasn't ended. Open Tugboat to try again.")
        }
    }
}
