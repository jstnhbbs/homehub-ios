import Foundation

struct ChoreWeekdayOption: Identifiable, Sendable {
    let value: String
    let label: String
    var id: String { value }
}

/// A chore's repeat as the app reasons about it: the unit and interval the server stores, and for
/// a daily chore the weekdays it runs on.
struct ChoreRepeatRule: Equatable, Sendable {
    var unit: ChoreRepeatUnit
    var interval: Int = 1
    /// Weekdays (0 = Sunday) a daily chore is limited to. Empty means every day.
    var weekdays: [String] = []

    static let never = ChoreRepeatRule(unit: .never)
    static let daily = ChoreRepeatRule(unit: .day)
    static let weekdaysOnly = ChoreRepeatRule(unit: .day, weekdays: ChoreHelpers.workWeek)
}

/// The choices in the Repeat menu. Anything that isn't one of these is "Custom".
enum ChoreRepeatPreset: String, CaseIterable, Identifiable, Sendable {
    case never
    case daily
    case weekdays
    case weekly
    case everyTwoWeeks
    case monthly
    case everyThreeMonths
    case yearly
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: "Never"
        case .daily: "Every Day"
        case .weekdays: "Weekdays"
        case .weekly: "Every Week"
        case .everyTwoWeeks: "Every 2 Weeks"
        case .monthly: "Every Month"
        case .everyThreeMonths: "Every 3 Months"
        case .yearly: "Every Year"
        case .custom: "Custom…"
        }
    }

    /// The rule a preset stands for. Custom has none of its own: the form supplies it.
    var rule: ChoreRepeatRule? {
        switch self {
        case .never: .never
        case .daily: .daily
        case .weekdays: .weekdaysOnly
        case .weekly: ChoreRepeatRule(unit: .week)
        case .everyTwoWeeks: ChoreRepeatRule(unit: .week, interval: 2)
        case .monthly: ChoreRepeatRule(unit: .month)
        case .everyThreeMonths: ChoreRepeatRule(unit: .month, interval: 3)
        case .yearly: ChoreRepeatRule(unit: .year)
        case .custom: nil
        }
    }

    static func matching(_ rule: ChoreRepeatRule) -> ChoreRepeatPreset {
        allCases.first { $0.rule == rule } ?? .custom
    }
}

enum ChoreHelpers {
    static let weekdayOptions: [ChoreWeekdayOption] = [
        .init(value: "1", label: "Monday"),
        .init(value: "2", label: "Tuesday"),
        .init(value: "3", label: "Wednesday"),
        .init(value: "4", label: "Thursday"),
        .init(value: "5", label: "Friday"),
        .init(value: "6", label: "Saturday"),
        .init(value: "0", label: "Sunday"),
    ]

    static let workWeek = ["1", "2", "3", "4", "5"]

    static func weeklyChoreDay(_ days: String) -> String {
        let trimmed = days.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 1, "0123456".contains(trimmed) {
            return trimmed
        }
        return "1"
    }

    static func weekdayLabel(_ day: String) -> String {
        weekdayOptions.first { $0.value == day }?.label ?? "Monday"
    }

    // MARK: Rules

    /// The rule a row has. A server that predates repeat rules sends only `cadence`.
    static func repeatRule(unit: ChoreRepeatUnit?, interval: Int?, cadence: ChoreCadence, days: String) -> ChoreRepeatRule {
        let resolved = unit ?? (cadence == .weekly ? .week : .day)
        let every = max(1, interval ?? 1)
        guard resolved == .day, every == 1 else {
            return ChoreRepeatRule(unit: resolved, interval: resolved == .never ? 1 : every)
        }
        let chosen = days.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.sorted()
        // Every day, or no days at all, is just daily.
        return ChoreRepeatRule(unit: .day, weekdays: chosen.count == 7 || chosen.isEmpty ? [] : chosen)
    }

    static func repeatRule(for row: ChoreRow) -> ChoreRepeatRule {
        repeatRule(unit: row.repeatUnit, interval: row.repeatInterval, cadence: row.cadence, days: row.days)
    }

    /// Whether the chore counts from its date, so the date can't be left out.
    static func needsDate(_ rule: ChoreRepeatRule) -> Bool {
        switch rule.unit {
        case .never: false
        case .week, .month, .year: true
        case .day: rule.interval > 1
        }
    }

    /// The server's list of weekdays to send for a rule, or nil when it doesn't apply.
    static func sentWeekdays(_ rule: ChoreRepeatRule) -> [String]? {
        rule.unit == .day && rule.interval == 1 && !rule.weekdays.isEmpty ? rule.weekdays : nil
    }

    static func input(
        title: String,
        profileId: String?,
        rule: ChoreRepeatRule,
        dueDate: String?,
        dueTime: String?,
        weekDay: String?
    ) -> ChoreInput {
        ChoreInput(
            title: title,
            profileId: profileId,
            cadence: rule.unit == .day ? .daily : .weekly,
            repeatUnit: rule.unit,
            repeatInterval: rule.unit == .never ? nil : rule.interval,
            weekDay: rule.unit == .week ? weekDay : nil,
            weekdays: sentWeekdays(rule),
            dueDate: dueDate,
            dueTime: dueTime
        )
    }

    // MARK: Text

    /// "Every day", "Every 2 weeks · Wednesday", "Every month · on the 15th" and so on. `dueDate` is
    /// the date a month or year counts from.
    static func repeatDetail(
        rule: ChoreRepeatRule,
        days: String,
        dueDate: String?,
        timezone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let every = rule.interval
        switch rule.unit {
        case .never:
            return "Doesn't repeat"
        case .day:
            if every > 1 { return "Every \(every) days" }
            if rule.weekdays.isEmpty { return "Every day" }
            if rule.weekdays == workWeek { return "Weekdays" }
            let names = weekdayOptions.filter { rule.weekdays.contains($0.value) }.map { String($0.label.prefix(3)) }
            return "Every " + names.joined(separator: ", ")
        case .week:
            let base = every == 1 ? "Every week" : "Every \(every) weeks"
            return "\(base) · \(weekdayLabel(weeklyChoreDay(days)))"
        case .month:
            let base = every == 1 ? "Every month" : "Every \(every) months"
            guard let day = dayOfMonth(dueDate) else { return base }
            return "\(base) · on the \(ordinal(day, locale: locale))"
        case .year:
            let base = every == 1 ? "Every year" : "Every \(every) years"
            guard let dueDate else { return base }
            return "\(base) · \(DateHelpers.formatLocalDate(dueDate, timezone: timezone, pattern: "MMM d", locale: locale))"
        }
    }

    static func repeatDetail(for row: ChoreRow, timezone: TimeZone) -> String {
        repeatDetail(rule: repeatRule(for: row), days: row.days, dueDate: row.dueDate, timezone: timezone)
    }

    /// "5:30 PM", or "17:30" where the person's clock is 24-hour, from the stored "HH:mm".
    static func timeLabel(_ time: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard let (hour, minute) = hourAndMinute(time) else { return time }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute)) else {
            return time
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func hourAndMinute(_ time: String) -> (Int, Int)? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }

    /// The minute of the day ("17:30" is 1050), for comparing and for notification times.
    static func minuteOfDay(_ time: String) -> Int? {
        hourAndMinute(time).map { $0.0 * 60 + $0.1 }
    }

    /// What the line under a chore says about when it is due, or nil when there is nothing to say:
    /// "Overdue · Fri, Oct 9 · 5:30 PM", "Due Fri, Oct 9", "Due by 5:30 PM".
    static func dueLine(
        for row: ChoreRow,
        timezone: TimeZone,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        let rule = repeatRule(for: row)
        var parts: [String] = []
        if rule.unit == .never, let dueDate = row.dueDate {
            parts.append(DateHelpers.formatLocalDate(dueDate, timezone: timezone, pattern: "EEE, MMM d", locale: locale))
        }
        if let time = row.dueTime {
            parts.append(timeLabel(time, locale: locale))
        }
        guard !parts.isEmpty else { return nil }
        if row.overdue == true { return "Overdue · " + parts.joined(separator: " · ") }
        // "Due Fri, Oct 9", "Due Fri, Oct 9 · 5:30 PM" and "Due by 5:30 PM" for a time alone.
        return rule.unit == .never ? "Due " + parts.joined(separator: " · ") : "Due by " + parts.joined(separator: " · ")
    }

    private static func dayOfMonth(_ localDate: String?) -> Int? {
        guard let localDate else { return nil }
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? parts[2] : nil
    }

    private static func ordinal(_ number: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}
