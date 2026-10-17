import ActivityKit
import Foundation

/// Keeps the lock screen and Dynamic Island in step with whoever is napping.
///
/// Naps only: a night's sleep outlasts the eight hours iOS gives a Live Activity, and a name and timer on the
/// lock screen all night is not what anyone wants. A night sleep that is still running in the morning gets a
/// reminder instead (`SleepNudgePlanner`). There is one Live Activity per running nap. `sync` is cheap and idempotent, so it runs whenever
/// fresh data arrives (dashboard refresh, Sleep page load): it starts an activity for a sleep that
/// has none, corrects one whose start time was edited, and ends any whose sleep has finished or was
/// deleted. Activities can only be started while the app is in the foreground, so a nap started on
/// another device appears here the next time the app refreshes.
@MainActor
enum SleepLiveActivityManager {
    private static let workQueue = NotificationWorkQueue()

    static func sync(logs: [NapLog], children: [Profile]) async {
        await workQueue.schedule { isCurrent in
            await apply(logs: logs, children: children, isCurrent: isCurrent)
        }
    }

    private static func apply(logs: [NapLog], children: [Profile], isCurrent: @MainActor () -> Bool) async {
        // A nap whose End was tapped on the Lock Screen with no connection is waiting to be sent: the server
        // still shows it running, but it must not come back.
        let waitingToEnd = Set(WidgetPendingQueue().load().filter { $0.action == "endSleep" }.map(\.itemId))
        var wanted: [String: (log: NapLog, child: Profile)] = [:]
        for child in children {
            if let log = NapHelpers.activeSleep(for: child.id, in: logs), log.kind == "nap", !waitingToEnd.contains(log.id) {
                wanted[log.id] = (log, child)
            }
        }

        var seen = Set<String>()
        for activity in Activity<SleepActivityAttributes>.activities {
            guard isCurrent() else { return }
            let id = activity.attributes.sleepId
            guard let entry = wanted[id], seen.insert(id).inserted else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            if activity.content.state.startedAt != entry.log.startedAt {
                await activity.update(ActivityContent(state: .init(startedAt: entry.log.startedAt), staleDate: nil))
            }
        }

        guard isCurrent(), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let running = Set(Activity<SleepActivityAttributes>.activities.map(\.attributes.sleepId))
        for (id, entry) in wanted where !running.contains(id) {
            guard isCurrent() else { return }
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
        await clearSessionActivities().value
    }

    /// Invalidate in-flight syncs immediately, then end activities after their OS writes finish.
    static func clearSessionActivities() -> Task<Void, Never> {
        workQueue.reset {
            for activity in Activity<SleepActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
