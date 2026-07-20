import Foundation

enum DateHelpers {
    static func localDateIn(timezone: TimeZone, date: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
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

    static func weekdayShort(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func dayNumber(_ date: Date, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return String(calendar.component(.day, from: date))
    }

    static func weekKey(for date: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    static func formatLocalDate(_ localDate: String, timezone: TimeZone, style: DateFormatter.Style = .medium) -> String {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return localDate }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        guard let date = calendar.date(from: components) else { return localDate }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateStyle = style
        return formatter.string(from: date)
    }

    static func timeString(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func headerDateLabel(timezone: TimeZone, date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}
