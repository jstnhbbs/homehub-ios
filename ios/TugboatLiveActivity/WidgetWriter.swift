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
    static func perform(action: String, itemId: String, userId: String, householdId: String, localDate: String) async throws {
        let store = WidgetStore()
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

        // The send starts now, in this extension, rather than after it returns: nothing else will send a tap this
        // fresh (the widget's timeline leaves it alone for a few seconds), and an extension is not guaranteed to
        // keep running once its action has returned.
        let send = Task.detached { await WidgetSync.flush() }
        // A ticked row shows as a filled check for a moment (the redraw asked for above), then lets go on the
        // prompt redraw that follows this returning.
        if action == "step" || action == "chore" {
            try? await Task.sleep(nanoseconds: UInt64(WidgetRecentTaps.lingerSeconds * 1_000_000_000))
        }
        // Keep the extension alive to finish the send after this returns.
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Tugboat widget action") { expired in
            guard !expired else { return }   // still on the waiting list; the next send gets it
            let finished = DispatchSemaphore(value: 0)
            Task.detached {
                await send.value
                // The tap that is waiting redraws as "Waiting to sync"; one that went through needs nothing.
                for kind in WidgetActionPolicy.affectedKinds(action: action) { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
                finished.signal()
            }
            finished.wait()
        }
    }
}
