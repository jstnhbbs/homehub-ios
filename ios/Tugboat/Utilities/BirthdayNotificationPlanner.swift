import Foundation

/// When and how far ahead to remind about birthdays.
struct BirthdayReminderOptions: Equatable, Sendable {
    var onTheDay: Bool
    /// Days of advance notice, such as `[1, 7]`. Zero and negative values are ignored.
    var leadDays: [Int]
    var minuteOfDay: Int
}

struct PlannedBirthdayReminder: Equatable, Sendable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Turns upcoming birthdays and the person's choices into concrete reminders. It only plans;
/// the notification service turns each one into a local notification.
enum BirthdayNotificationPlanner {
    /// Advance-notice choices offered in Settings, in days.
    static let leadDayChoices = [1, 3, 7, 14]
    static let defaultMinuteOfDay = 8 * 60

    /// iOS keeps at most 64 pending local notifications per app and other reminders share that
    /// budget, so birthdays are capped and the soonest ones win.
    static let maxReminders = 30

    static func plan(
        items: [BirthdayItem],
        options: BirthdayReminderOptions,
        timezone: TimeZone,
        now: Date = .now,
        locale: Locale = .autoupdatingCurrent,
        limit: Int = maxReminders
    ) -> [PlannedBirthdayReminder] {
        var offsets = Set(options.leadDays.filter { $0 > 0 })
        if options.onTheDay {
            offsets.insert(0)
        }
        guard !offsets.isEmpty else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let minuteOfDay = max(0, min(24 * 60 - 1, options.minuteOfDay))
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60

        var reminders: [PlannedBirthdayReminder] = []
        for item in items {
            guard let birthday = DateHelpers.dateFromLocalDate(item.nextDate, timezone: timezone) else { continue }
            for offset in offsets.sorted() {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: birthday),
                      let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      fireDate > now else { continue }
                reminders.append(
                    PlannedBirthdayReminder(
                        id: "birthday.\(item.id).\(offset)",
                        fireDate: fireDate,
                        title: title(for: item, leadDays: offset),
                        body: body(for: item, leadDays: offset, birthday: birthday, timezone: timezone, locale: locale)
                    )
                )
            }
        }

        return Array(
            reminders
                .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
                .prefix(limit)
        )
    }

    /// "1 Day Before", "1 Week Before", and so on, for the Settings list.
    static func leadLabel(_ days: Int) -> String {
        switch days {
        case 1: "1 Day Before"
        case 7: "1 Week Before"
        case 14: "2 Weeks Before"
        default: "\(days) Days Before"
        }
    }

    static func leadPhrase(_ days: Int) -> String {
        switch days {
        case 1: "tomorrow"
        case 7: "in 1 week"
        case 14: "in 2 weeks"
        default: "in \(days) days"
        }
    }

    private static func title(for item: BirthdayItem, leadDays: Int) -> String {
        leadDays == 0
            ? "\(item.name)'s \(item.kind.noun)"
            : "\(item.name)'s \(item.kind.noun) is \(leadPhrase(leadDays))"
    }

    private static func body(
        for item: BirthdayItem,
        leadDays: Int,
        birthday: Date,
        timezone: TimeZone,
        locale: Locale
    ) -> String {
        let hasAge = (1...120).contains(item.upcomingAge)
        if leadDays == 0 {
            guard hasAge else { return "It's \(item.name)'s \(item.kind.noun) today." }
            switch item.kind {
            case .birthday:
                return "\(item.name) turns \(item.upcomingAge) today."
            case .anniversary:
                // The title already says whose anniversary it is, so the body needs no verb.
                return "\(yearsPhrase(item.upcomingAge)) today."
            }
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timezone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        let date = formatter.string(from: birthday)
        guard hasAge else { return "\(item.name)'s \(item.kind.noun) is on \(date)." }
        switch item.kind {
        case .birthday:
            return "\(item.name) turns \(item.upcomingAge) on \(date)."
        case .anniversary:
            return "\(yearsPhrase(item.upcomingAge)) on \(date)."
        }
    }

    private static func yearsPhrase(_ years: Int) -> String {
        years == 1 ? "1 year" : "\(years) years"
    }
}
