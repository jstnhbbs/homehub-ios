import Foundation

enum DashboardHelpers {
    /// Matches web `TodaySchedule`: all-day events stay visible; timed events drop after they end.
    static func upcomingScheduleEvents(_ events: [ScheduleEvent], now: Date) -> [ScheduleEvent] {
        events.filter { $0.allDay || $0.endsAt > now }
    }

    static func nextTimedEventEnd(after now: Date, in events: [ScheduleEvent]) -> Date? {
        events
            .filter { !$0.allDay && $0.endsAt > now }
            .map(\.endsAt)
            .min()
    }

    static func mealLines(_ title: String) -> [String] {
        title
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
