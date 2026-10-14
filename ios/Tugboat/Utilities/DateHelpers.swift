import Foundation

enum DateHelpers {
    /// Calendars and formatters are expensive to build and the Sleep page alone asks for hundreds of
    /// them per render, so each one is made once per time zone and format and reused.
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var calendars: [String: Calendar] = [:]
        private var formatters: [String: DateFormatter] = [:]

        func calendar(in timezone: TimeZone) -> Calendar {
            lock.lock()
            defer { lock.unlock() }
            if let cached = calendars[timezone.identifier] { return cached }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timezone
            calendars[timezone.identifier] = calendar
            return calendar
        }

        func formatter(key: String, make: () -> DateFormatter) -> DateFormatter {
            lock.lock()
            defer { lock.unlock() }
            if let cached = formatters[key] { return cached }
            let formatter = make()
            formatters[key] = formatter
            return formatter
        }
    }

    private static let cache = Cache()

    /// A Gregorian calendar in `timezone`, shared between callers. Don't mutate it; copy first.
    static func gregorian(in timezone: TimeZone) -> Calendar {
        cache.calendar(in: timezone)
    }

    /// A formatter for `pattern`, read as a *template*: the letters say which parts to show ("EEE, MMM d"
    /// means weekday, month and day) and the person's region decides the wording, order and
    /// punctuation. A US household sees exactly what the pattern spells out ("Mon, Oct 5"); a UK one sees
    /// "Mon, 5 Oct". The literal punctuation in the pattern is ignored for that reason.
    private static func patternFormatter(_ pattern: String, timezone: TimeZone, locale: Locale) -> DateFormatter {
        cache.formatter(key: "\(timezone.identifier)|\(locale.identifier)|\(pattern)") {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timezone
            formatter.setLocalizedDateFormatFromTemplate(String(pattern.filter { $0.isLetter }))
            return formatter
        }
    }

    static func localDateIn(timezone: TimeZone, date: Date = .now) -> String {
        let calendar = gregorian(in: timezone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ISO8601DateFormatter().string(from: date).prefix(10).description
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func weekDates(
        from date: Date = .now,
        timezone: TimeZone = .current,
        weekStartsOn: Int = WeekStart.defaultWeekStartsOn
    ) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.firstWeekday = weekStartsOn == 0 ? 1 : weekStartsOn + 1
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func weekdayShort(_ date: Date, timezone: TimeZone, locale: Locale = .autoupdatingCurrent) -> String {
        patternFormatter("EEE", timezone: timezone, locale: locale).string(from: date)
    }

    static func dayNumber(_ date: Date, timezone: TimeZone) -> String {
        String(gregorian(in: timezone).component(.day, from: date))
    }

    static func formatLocalDate(_ localDate: String, timezone: TimeZone, style: DateFormatter.Style = .medium) -> String {
        guard let date = dateFromLocalDate(localDate, timezone: timezone) else { return localDate }
        let formatter = cache.formatter(key: "\(timezone.identifier)|style|\(style.rawValue)") {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.timeZone = timezone
            formatter.dateStyle = style
            formatter.timeStyle = .none
            return formatter
        }
        return formatter.string(from: date)
    }

    static func formatLocalDate(_ localDate: String, timezone: TimeZone, pattern: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard let date = dateFromLocalDate(localDate, timezone: timezone) else { return localDate }
        return patternFormatter(pattern, timezone: timezone, locale: locale).string(from: date)
    }

    static func dateFromLocalDate(_ localDate: String, timezone: TimeZone) -> Date? {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let calendar = gregorian(in: timezone)
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    static func timeString(_ date: Date, timezone: TimeZone) -> String {
        let formatter = cache.formatter(key: "\(timezone.identifier)|short-time") {
            let formatter = DateFormatter()
            formatter.timeZone = timezone
            formatter.timeStyle = .short
            return formatter
        }
        return formatter.string(from: date)
    }

    static func headerDateLabel(timezone: TimeZone, date: Date = .now, locale: Locale = .autoupdatingCurrent) -> String {
        patternFormatter("EEEE, MMMM d", timezone: timezone, locale: locale).string(from: date)
    }
}
