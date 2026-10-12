import Foundation

/// A sleep on a child's log for the day: what it was, when, and for how long.
struct SleepEntry: Identifiable {
    let id: String
    /// "Nap" or "Night".
    let title: String
    /// "9:10 AM – 10:20 AM", or "since 7:30 PM" while it is still going.
    let range: String
    let duration: String
}

/// What the Sleep card says at each size.
struct SleepCardSummary {
    let children: [Profile]
    let logs: [NapLog]
    let localDate: String
    let timezone: TimeZone
    let now: Date

    func status(for child: Profile) -> ChildDashboardSleepStatus {
        NapHelpers.getChildDashboardSleepStatus(logs: logs, profileId: child.id, localDate: localDate, timezone: timezone, now: now)
    }

    private var statuses: [(profile: Profile, status: ChildDashboardSleepStatus)] {
        children.map { ($0, status(for: $0)) }
    }

    private func isAsleep(_ status: ChildDashboardSleepStatus) -> Bool {
        status.state == .napping || status.state == .inBed
    }

    /// Children asleep now.
    var asleepCount: Int { statuses.filter { isAsleep($0.status) }.count }

    /// Whose story the Small card tells: whoever has been asleep longest, otherwise whoever has been
    /// awake longest (of those with something logged today).
    var lead: (profile: Profile, status: ChildDashboardSleepStatus)? {
        let asleep = statuses.filter { isAsleep($0.status) }.max { $0.status.durationMinutes < $1.status.durationMinutes }
        if let asleep { return asleep }
        return statuses.filter { $0.status.state == .awake }.max { $0.status.durationMinutes < $1.status.durationMinutes }
    }

    /// The big words on a Small card: how long they have been asleep or awake.
    var headline: String {
        if children.isEmpty { return "No children" }
        guard let lead else { return "No sleep" }
        return NapHelpers.formatDuration(minutes: lead.status.durationMinutes)
    }

    /// The line under it.
    var caption: String {
        if children.isEmpty { return "Add a child profile" }
        guard let lead else { return "logged today" }
        let name = lead.profile.name.split(separator: " ").first.map(String.init) ?? lead.profile.name
        switch lead.status.state {
        case .napping: return "\(name) napping"
        case .inBed: return "\(name) in bed"
        default: return "\(name) awake"
        }
    }

    /// The one line above a Medium or Large card's rows.
    var line: String {
        if children.isEmpty { return "No children" }
        if asleepCount > 0 { return asleepCount == 1 ? "1 asleep now" : "\(asleepCount) asleep now" }
        return statuses.contains { $0.status.state != .empty } ? "Everyone awake" : "No sleep logged today"
    }

    /// One child's sleeps for the day, in order.
    func entries(for child: Profile) -> [SleepEntry] {
        NapHelpers.logsForDate(profileId: child.id, in: logs, localDate: localDate, timezone: timezone, now: now)
            .sorted { $0.startedAt < $1.startedAt }
            .map { log in
                let start = DateHelpers.timeString(log.startedAt, timezone: timezone)
                let range = log.endedAt.map { "\(start) – \(DateHelpers.timeString($0, timezone: timezone))" } ?? "since \(start)"
                return SleepEntry(
                    id: log.id,
                    title: log.kind == "night" ? "Night" : "Nap",
                    range: range,
                    duration: NapHelpers.formatDuration(minutes: NapHelpers.durationMinutes(startedAt: log.startedAt, endedAt: log.endedAt, now: now))
                )
            }
    }
}
