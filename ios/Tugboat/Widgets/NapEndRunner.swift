import ActivityKit
import Foundation
import WidgetKit

/// The End button on a nap's Live Activity. It runs in the app's process (a Live Activity intent does).
///
/// The Lock Screen answers first: the activity is ended at once. The write then goes through the same waiting
/// list as a widget tap (`WidgetPendingQueue`), so with no connection it waits and is sent later, with the time
/// it was tapped, and the Sleep widget shows the nap as ended meanwhile.
@MainActor
enum NapEndRunner {
    static func perform(sleepId: String) async {
        for activity in Activity<SleepActivityAttributes>.activities where activity.attributes.sleepId == sleepId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let store = WidgetStore()
        if let saved = store.load(), saved.serverURL != nil,
           let pending = WidgetPendingAction.make(action: "endSleep", itemId: sleepId, in: saved) {
            var early = WidgetActionPolicy.applying(action: "endSleep", itemId: sleepId, to: saved, at: pending.tappedAt)
            early.actionError = nil
            WidgetPendingQueue().enqueue(pending)
            _ = store.save(early, force: true)
            for kind in WidgetActionPolicy.affectedKinds(action: "endSleep") { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
            await WidgetSync.flush()
        } else {
            // No saved copy of the household's data to queue against (signed out, or an old build): send it now.
            _ = try? await TugboatAPI(baseURL: AppConfig.baseURL).endNap(napId: sleepId)
        }
        NotificationCenter.default.post(name: .tugboatDataChanged, object: nil)
    }
}
