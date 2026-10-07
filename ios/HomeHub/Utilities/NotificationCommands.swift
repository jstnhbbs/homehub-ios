import Foundation

/// What a button on a notification asks the app to do. Foundation only, so the decoding can be
/// checked from the command line (`ios/checks/notification-commands`).
enum NotificationCommand: Equatable, Sendable {
    /// Mark a chore done for the period the reminder was about.
    case completeChore(choreId: String, periodKey: String, title: String)
    /// End a running nap.
    case endNap(napId: String, name: String)
}

enum NotificationCommands {
    // Categories say which buttons a notification gets; actions say which button was pressed.
    static let choreCategory = "beacon.chore"
    static let napCategory = "beacon.nap"
    static let doneAction = "beacon.done"
    static let endNapAction = "beacon.endNap"

    /// What a chore reminder carries so its Done button knows which chore and which period.
    static func choreInfo(choreId: String, periodKey: String, title: String) -> [String: String] {
        ["kind": "chore", "choreId": choreId, "periodKey": periodKey, "title": title]
    }

    /// What a nap check carries so its End Nap button knows which nap.
    static func napInfo(napId: String, name: String) -> [String: String] {
        ["kind": "nap", "napId": napId, "name": name]
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
        case (endNapAction, "nap"):
            guard let napId = text("napId") else { return nil }
            return .endNap(napId: napId, name: text("name") ?? "Nap")
        default:
            return nil
        }
    }

    /// What to tell the person when a button could not do its job (no connection, signed out), so
    /// a chore never looks done when it is not.
    static func failureMessage(for command: NotificationCommand) -> (title: String, body: String) {
        switch command {
        case .completeChore(_, _, let title):
            return ("Couldn't mark it done", "\(title) wasn't marked done. Open Beacon to try again.")
        case .endNap(_, let name):
            return ("Couldn't end the nap", "\(name)'s nap wasn't ended. Open Beacon to try again.")
        }
    }
}
