import Foundation
import WidgetKit

/// Runs a widget check-off or End Sleep inside the extension.
///
/// The change is shown first, from the saved snapshot, and this returns so iOS can redraw the widget at
/// once. The tap is saved to the waiting list (`WidgetPendingQueue`) before anything is sent, so it survives
/// the extension being stopped and a missing connection: it is sent behind the redraw, and if there is no
/// connection it stays on the list and the widget says "Waiting to sync" until a later send (the next tap, the
/// widget's next refresh, or the app) gets it through. A tap the server refuses is undone and the reason shown.
/// The sign-in is the app's own session, read from the Keychain item the app and this extension share.
enum WidgetWriter {
    static func perform(action: String, itemId: String, userId: String, householdId: String, localDate: String,
                        holdSeconds: TimeInterval = 0) async throws {
        let store = WidgetStore()
        let tapped = Date()
        guard let saved = store.load(), saved.userId == userId, saved.householdId == householdId,
              saved.serverURL != nil else { throw WidgetActionFailure.openApp }
        guard let early = WidgetActionPolicy.appliedEarly(action: action, itemId: itemId, userId: userId,
                                                          householdId: householdId, localDate: localDate, to: saved),
              let pending = WidgetPendingAction.make(action: action, itemId: itemId, in: saved)
        else { throw WidgetActionFailure.stale }
        // Waiting first, then shown: a tap that is shown must also be remembered.
        WidgetPendingQueue().enqueue(pending)
        guard store.save(early, force: true) else { throw WidgetActionFailure.failed }
        // Other widgets that show the same item. The one that was tapped redraws when this returns.
        for kind in WidgetActionPolicy.affectedKinds(action: action) { WidgetCenter.shared.reloadTimelines(ofKind: kind) }

        // The durable queue survives extension suspension. Try now within a real network deadline,
        // then return for WidgetKit's redraw; a future timeline or the app retries anything left.
        await WidgetSync.flush(timeout: 1)
        let hold = holdSeconds - Date().timeIntervalSince(tapped)
        if hold > 0 { try? await Task.sleep(for: .seconds(hold)) }
    }
}
