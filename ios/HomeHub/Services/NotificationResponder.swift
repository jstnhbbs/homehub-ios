import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted after a button on a notification changed something on the server, so a running app
    /// refreshes what it shows.
    static let homeHubDataChanged = Notification.Name("homehub.dataChanged")
}

/// Handles the buttons on Beacon's notifications ("Done" on a chore reminder, "End Nap" on a nap
/// check). The system runs this even when the app is not open, and the same buttons show on an
/// Apple Watch paired with the phone, so a chore can be ticked off from the wrist.
///
/// It talks to the server with its own client: that reads the saved session from the Keychain, so
/// it does not depend on the app having been opened first. It is set as the notification center's
/// delegate in `HomeHubApp.init`, early enough for a launch the button itself caused.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationResponder()

    /// Tells the system which buttons each kind of notification has. Call at launch.
    static func registerCategories() {
        let done = UNNotificationAction(identifier: NotificationCommands.doneAction, title: "Done", options: [])
        let endNap = UNNotificationAction(identifier: NotificationCommands.endNapAction, title: "End Nap", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: NotificationCommands.choreCategory, actions: [done], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCommands.napCategory, actions: [endNap], intentIdentifiers: [], options: []),
        ])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let command = NotificationCommands.command(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        ) else {
            completionHandler()
            return
        }
        // The system lets the app run only until the handler is called, so it is called when the
        // request has finished, not before.
        let finish = UncheckedHandler(completionHandler)
        Task { @MainActor in
            await Self.perform(command)
            finish.call()
        }
    }

    @MainActor
    private static func perform(_ command: NotificationCommand) async {
        let api = HomeHubAPI(baseURL: AppConfig.baseURL)
        do {
            switch command {
            case .completeChore(let choreId, let periodKey, _):
                try await api.toggleChore(ToggleChoreRequest(choreId: choreId, periodKey: periodKey, completed: true))
            case .endNap(let napId, _):
                try await api.endNap(napId: napId)
            }
            NotificationCenter.default.post(name: .homeHubDataChanged, object: nil)
        } catch {
            await reportFailure(of: command)
        }
    }

    /// Says right away that the button did not work. Its identifier does not start with the one
    /// the reminder planner owns, so planning reminders cannot remove it.
    private static func reportFailure(of command: NotificationCommand) async {
        let message = NotificationCommands.failureMessage(for: command)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "homehub.action.failed.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// The system's completion handler is not marked Sendable but is safe to call from any thread.
private final class UncheckedHandler: @unchecked Sendable {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    func call() { handler() }
}
