import Foundation

/// What the Schedule card says at each size, from today's and tomorrow's calendar events.
struct ScheduleCardSummary {
    /// Today's events, including ones already over.
    let today: [ScheduleEvent]
    let tomorrow: [ScheduleEvent]
    let now: Date
    let timezone: TimeZone
    /// Whether the device's calendar is available at all.
    let isConnected: Bool

    /// All-day events first, then the rest by when they start.
    private func listed(_ events: [ScheduleEvent]) -> [ScheduleEvent] {
        events.enumerated().sorted { a, b in
            if a.element.allDay != b.element.allDay { return a.element.allDay }
            if a.element.startsAt != b.element.startsAt { return a.element.startsAt < b.element.startsAt }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// What is still to come today (or on now), all-day events first.
    var todayLeft: [ScheduleEvent] { listed(DashboardHelpers.upcomingScheduleEvents(today, now: now)) }
    var tomorrowAll: [ScheduleEvent] { listed(tomorrow) }

    private func time(_ event: ScheduleEvent) -> String {
        event.allDay ? "All day" : DateHelpers.timeString(event.startsAt, timezone: timezone)
    }

    /// The big words on a Small card: when the next thing starts.
    var headline: String {
        guard isConnected else { return "Not connected" }
        if let next = todayLeft.first(where: { !$0.allDay }) {
            return next.startsAt <= now ? "Now" : time(next)
        }
        if todayLeft.first != nil { return "All day" }
        if tomorrowAll.first != nil { return "Tomorrow" }
        return "Free"
    }

    /// The line under it: what it is.
    var caption: String {
        guard isConnected else { return "Connect a calendar to see events" }
        if let next = todayLeft.first(where: { !$0.allDay }) { return next.title }
        if let first = todayLeft.first { return first.title }
        if let first = tomorrowAll.first { return "\(first.title) · \(time(first))" }
        return "Nothing on the calendar"
    }

    /// The one line above a Medium or Large card's rows.
    var line: String {
        guard isConnected else { return "Not connected" }
        let count = todayLeft.count
        if count == 0 { return today.isEmpty ? "Nothing on the calendar today" : "Nothing left today" }
        return count == 1 ? "1 event left today" : "\(count) events left today"
    }
}
