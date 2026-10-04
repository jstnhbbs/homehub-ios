import ActivityKit
import Foundation

/// Keeps the lock screen and Dynamic Island in step with whoever is asleep.
///
/// There is one Live Activity per active sleep. `sync` is cheap and idempotent, so it runs whenever
/// fresh data arrives (dashboard refresh, Sleep page load): it starts an activity for a sleep that
/// has none, corrects one whose start time was edited, and ends any whose sleep has finished or was
/// deleted. Activities can only be started while the app is in the foreground, so a nap started on
/// another device appears here the next time the app refreshes.
@MainActor
enum SleepLiveActivityManager {
    static func sync(logs: [NapLog], children: [Profile]) async {
        var wanted: [String: (log: NapLog, child: Profile)] = [:]
        for child in children {
            if let log = NapHelpers.activeSleep(for: child.id, in: logs) {
                wanted[log.id] = (log, child)
            }
        }

        // Update or end what already exists. Awaits happen here, before the start step below, so no
        // other sync can slip in between reading the running activities and requesting new ones.
        var seen = Set<String>()
        for activity in Activity<SleepActivityAttributes>.activities {
            let id = activity.attributes.sleepId
            guard let entry = wanted[id], seen.insert(id).inserted else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            if activity.content.state.startedAt != entry.log.startedAt {
                await activity.update(ActivityContent(state: .init(startedAt: entry.log.startedAt), staleDate: nil))
            }
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = Set(Activity<SleepActivityAttributes>.activities.map(\.attributes.sleepId))
        for (id, entry) in wanted where !running.contains(id) {
            let attributes = SleepActivityAttributes(
                sleepId: id,
                profileId: entry.child.id,
                childName: entry.child.name,
                colorHex: entry.child.color,
                kind: entry.log.kind
            )
            _ = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: .init(startedAt: entry.log.startedAt), staleDate: nil),
                pushType: nil
            )
        }
    }

    static func endAll() async {
        for activity in Activity<SleepActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
