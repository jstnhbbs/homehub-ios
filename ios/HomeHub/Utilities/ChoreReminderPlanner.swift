import Foundation

/// A reminder for one chore that has a time.
struct ChoreReminder: Equatable, Sendable {
    var id: String
    var title: String
    var body: String
    var fireDate: Date
}

/// Works out the reminders for chores that have a time: today's that are still to do and the next
/// few days' (sent ahead by the server), each a set time before the chore is due.
enum ChoreReminderPlanner {
    /// "Before" choices in minutes; 0 is at the time itself.
    static let leadChoices = [0, 5, 10, 15, 30, 60, 120]

    static func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<1: "At the time"
        case 60: "1 hour before"
        case let value where value > 60 && value % 60 == 0: "\(value / 60) hours before"
        default: "\(minutes) minutes before"
        }
    }

    static func reminders(
        today: [ChoreRow],
        upcoming: [UpcomingChore],
        localDate: String,
        leadMinutes: Int,
        now: Date,
        calendar: Calendar,
        locale: Locale = .autoupdatingCurrent
    ) -> [ChoreReminder] {
        let todays = today
            .filter { !$0.completed && $0.dueToday != false }
            .compactMap { row in
                row.dueTime.map { (id: row.id, title: row.title, date: localDate, time: $0) }
            }
        let ahead = upcoming.map { (id: $0.id, title: $0.title, date: $0.date, time: $0.dueTime) }

        return (todays + ahead).compactMap { chore in
            guard let minute = ChoreHelpers.minuteOfDay(chore.time),
                  let day = DateHelpers.dateFromLocalDate(chore.date, timezone: calendar.timeZone),
                  let due = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day),
                  due > now else {
                return nil
            }
            let early = due.addingTimeInterval(-Double(max(0, leadMinutes)) * 60)
            // Already inside the lead time (opened the app ten minutes before a chore due in ten,
            // asked to be told half an hour before): tell them at the time rather than not at all.
            let isEarly = leadMinutes > 0 && early > now
            return ChoreReminder(
                id: "chore.\(chore.id).\(chore.date)",
                title: chore.title,
                body: isEarly ? "Due at \(ChoreHelpers.timeLabel(chore.time, locale: locale))." : "This chore is due now.",
                fireDate: isEarly ? early : due
            )
        }
    }
}
