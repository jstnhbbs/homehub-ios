import Foundation

enum CalendarHelpers {
    static func calendar(timezone: TimeZone, weekStartsOn: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        cal.firstWeekday = weekStartsOn == 0 ? 1 : min(7, weekStartsOn + 1)
        return cal
    }

    static func parseLocalDate(_ value: String, timezone: TimeZone) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let calendar = calendar(timezone: timezone, weekStartsOn: 1)
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return calendar.date(from: components)
    }

    static func localDate(for date: Date, timezone: TimeZone) -> String {
        DateHelpers.localDateIn(timezone: timezone, date: date)
    }

    static func monthTitle(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func weekTitle(start: Date, end: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.timeZone = timezone
        yearFormatter.dateFormat = "yyyy"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end)), \(yearFormatter.string(from: end))"
    }

    static func agendaTitle(_ localDate: String, timezone: TimeZone) -> String {
        DateHelpers.formatLocalDate(localDate, timezone: timezone, style: .full)
    }

    static func monthGridDates(anchor: Date, timezone: TimeZone, weekStartsOn: Int) -> [Date] {
        let cal = calendar(timezone: timezone, weekStartsOn: weekStartsOn)
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchor)),
              let monthRange = cal.range(of: .day, in: .month, for: anchor) else {
            return []
        }
        let gridStart = cal.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        let lastDay = cal.date(byAdding: .day, value: monthRange.count - 1, to: monthStart) ?? monthStart
        let gridEndWeek = cal.dateInterval(of: .weekOfYear, for: lastDay)?.end ?? lastDay
        var days: [Date] = []
        var cursor = gridStart
        while cursor < gridEndWeek {
            days.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    static func weekDates(anchor: Date, timezone: TimeZone, weekStartsOn: Int) -> [Date] {
        let cal = calendar(timezone: timezone, weekStartsOn: weekStartsOn)
        let start = cal.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func rangeStartEnd(viewMode: CalendarViewMode, anchor: Date, timezone: TimeZone, weekStartsOn: Int) -> (String, String) {
        let dates: [Date]
        switch viewMode {
        case .month:
            dates = monthGridDates(anchor: anchor, timezone: timezone, weekStartsOn: weekStartsOn)
        case .week:
            dates = weekDates(anchor: anchor, timezone: timezone, weekStartsOn: weekStartsOn)
        case .day:
            dates = [anchor]
        }
        guard let first = dates.first, let last = dates.last else {
            let today = localDate(for: anchor, timezone: timezone)
            return (today, today)
        }
        return (localDate(for: first, timezone: timezone), localDate(for: last, timezone: timezone))
    }

    static func eventsForDate(_ events: [CalendarOccurrence], on targetLocalDate: String, timezone: TimeZone) -> [CalendarOccurrence] {
        events
            .filter { localDate(for: $0.startsAt, timezone: timezone) == targetLocalDate }
            .sorted { $0.startsAt < $1.startsAt }
    }

    static func isSameMonth(_ date: Date, anchor: Date, timezone: TimeZone) -> Bool {
        let cal = calendar(timezone: timezone, weekStartsOn: 1)
        let d = cal.dateComponents([.year, .month], from: date)
        let a = cal.dateComponents([.year, .month], from: anchor)
        return d.year == a.year && d.month == a.month
    }

    static func formatFormDate(_ date: Date, allDay: Bool, timezone: TimeZone) -> String {
        if allDay {
            return localDate(for: date, timezone: timezone)
        }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.string(from: date)
    }

    static func parseFormDate(_ value: String, timezone: TimeZone) -> Date? {
        if value.contains("T") {
            let formatter = DateFormatter()
            formatter.timeZone = timezone
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return parseLocalDate(value, timezone: timezone)
    }

    static func defaultTimedFields(selectedDate: String, timezone: TimeZone) -> (startsAt: String, endsAt: String) {
        ("\(selectedDate)T09:00", "\(selectedDate)T10:00")
    }

    static func fieldValues(for event: CalendarOccurrence, timezone: TimeZone) -> (startsAt: String, endsAt: String) {
        if event.allDay {
            let start = localDate(for: event.startsAt, timezone: timezone)
            let inclusiveEnd = event.endsAt.timeIntervalSince(event.startsAt) <= 86_400
                ? start
                : localDate(for: event.endsAt.addingTimeInterval(-86_400), timezone: timezone)
            return (start, inclusiveEnd)
        }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return (formatter.string(from: event.startsAt), formatter.string(from: event.endsAt))
    }

    static func hourLabel(_ hour: Int, selectedDate: String, timezone: TimeZone) -> String {
        guard let date = parseLocalDate(selectedDate, timezone: timezone) else { return "" }
        let cal = calendar(timezone: timezone, weekStartsOn: 1)
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        guard let value = cal.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h a"
        return formatter.string(from: value)
    }

    static func eventHour(_ event: CalendarOccurrence, timezone: TimeZone) -> Int {
        let cal = calendar(timezone: timezone, weekStartsOn: 1)
        return cal.component(.hour, from: event.startsAt)
    }
}
