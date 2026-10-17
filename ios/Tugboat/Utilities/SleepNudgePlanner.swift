import Foundation

/// A reminder that a night sleep is still running.
struct SleepNudge: Equatable, Sendable {
    let id: String
    let fireDate: Date
    let sleepId: String
    let profileId: String
    /// When the sleep began, for the words ("since 8:15 PM").
    let startedAt: Date
}

/// Plans the morning "still asleep" reminders. Foundation only, checked in `ios/checks/sleep-nudge`.
///
/// A night sleep that nobody ends keeps counting, so the next morning's totals show a 20-hour night. Naps
/// have a Live Activity with an End button instead, so only night sleeps get this reminder.
///
/// The reminder is for the next time the chosen time of day comes round, whenever the sleep began. (An earlier
/// version also required the sleep to be four hours old, so one started just before the chosen time was
/// reminded a day later; that made the reminder impossible to try out and hid it from anyone who set an
/// evening time.)
enum SleepNudgePlanner {
    static func nudges(
        logs: [NapLog],
        minuteOfDay: Int,
        calendar: Calendar,
        now: Date
    ) -> [SleepNudge] {
        logs.compactMap { log -> SleepNudge? in
            guard log.kind == "night", log.endedAt == nil else { return nil }
            guard let fire = nextOccurrence(ofMinute: minuteOfDay, onOrAfter: max(now, log.startedAt), calendar: calendar) else { return nil }
            return SleepNudge(id: "sleep.night.\(log.id)", fireDate: fire, sleepId: log.id, profileId: log.profileId, startedAt: log.startedAt)
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    /// The first time of day `minuteOfDay` (0 to 1439, in the calendar's time zone) at or after `date`.
    static func nextOccurrence(ofMinute minuteOfDay: Int, onOrAfter date: Date, calendar: Calendar) -> Date? {
        let clamped = min(max(minuteOfDay, 0), 24 * 60 - 1)
        let start = calendar.startOfDay(for: date)
        for dayOffset in 0...2 {
            // Set the clock time rather than adding minutes to midnight: on the day the clocks change that is an
            // hour off.
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
                  let candidate = calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: day) else { continue }
            if candidate >= date { return candidate }
        }
        return nil
    }
}
