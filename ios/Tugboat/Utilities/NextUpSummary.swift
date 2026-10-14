import Foundation

/// One line of the "Coming Up" strip at the top of Today on iPhone.
struct NextUpItem: Equatable {
    enum Kind { case event, chore }
    enum Urgency {
        /// An event that has started and not finished.
        case now
        /// Still to come today.
        case soon
        /// A timed chore whose time has passed with nothing ticked.
        case overdue
    }

    let kind: Kind
    let urgency: Urgency
    let title: String
    /// When it is, and for a chore whose it is: "10:45 AM – 11:15 AM", "6:30 PM · Alex".
    let detail: String
    /// What the right-hand side says: "Now", "in 27 min", "in 2 hr 10 min", "at 6:30 PM", "Overdue".
    let status: String
}

enum NextUpSummary {
    /// How close something has to be for the strip to appear at all.
    static let leadMinutes = 60
    /// An event longer than this that has already started stays out of the strip.
    static let backgroundEventLength: TimeInterval = 4 * 3600
    /// How many lines the strip shows.
    static let maxItems = 3

    /// The few timed things that are pressing, across calendar events and chores, in time order; empty when
    /// nothing is. The strip exists to be the one place that looks across everything, so it stays out of the
    /// way unless something is on now, overdue, or starts within `leadMinutes`; once it is showing, it lists
    /// what comes after those too (up to `maxItems`), so the next couple of hours read as one line of sight.
    /// All-day events and chores with no time have no "next", and are left out. Only one missed chore is
    /// listed (the earliest), however many there are. `chores` and `events` are empty when that part of Today
    /// is switched off.
    static func upcoming(
        chores: [ChoreRow],
        events: [ScheduleEvent],
        profiles: [Profile],
        todayDate: String,
        timezone: TimeZone,
        now: Date
    ) -> [NextUpItem] {
        struct Candidate {
            let start: Date
            let isEvent: Bool
            let item: NextUpItem
        }

        func time(_ date: Date) -> String { DateHelpers.timeString(date, timezone: timezone) }

        let dayStart = DateHelpers.dateFromLocalDate(todayDate, timezone: timezone)
        func choreStart(_ chore: ChoreRow) -> Date? {
            guard let dayStart, let due = chore.dueTime, let (hour, minute) = ChoreHelpers.hourAndMinute(due) else { return nil }
            return DateHelpers.gregorian(in: timezone).date(byAdding: .minute, value: hour * 60 + minute, to: dayStart)
        }
        func personName(_ chore: ChoreRow) -> String? {
            profiles.first { $0.id == chore.profileId }?.name
        }

        var all: [Candidate] = []
        for event in events where !event.allDay && event.endsAt > now {
            let isOn = event.startsAt <= now
            // Something long that is already underway (a work block, a day at a fair) is the backdrop to the day,
            // not something to be reminded of; it would hold the strip open from morning to night.
            if isOn, event.endsAt.timeIntervalSince(event.startsAt) > backgroundEventLength { continue }
            all.append(Candidate(
                start: event.startsAt,
                isEvent: true,
                item: NextUpItem(
                    kind: .event,
                    urgency: isOn ? .now : .soon,
                    title: event.title,
                    detail: "\(time(event.startsAt)) – \(time(event.endsAt))",
                    status: isOn ? "Now" : relative(event.startsAt, from: now, clock: time)
                )
            ))
        }
        var missed: Candidate?
        for chore in chores where !chore.completed {
            guard let start = choreStart(chore) else { continue }
            let detail = [time(start), personName(chore)].compactMap { $0 }.joined(separator: " · ")
            if start >= now {
                all.append(Candidate(
                    start: start,
                    isEvent: false,
                    item: NextUpItem(kind: .chore, urgency: .soon, title: chore.title, detail: detail, status: relative(start, from: now, clock: time))
                ))
            } else if missed == nil || start < missed!.start {
                missed = Candidate(
                    start: start,
                    isEvent: false,
                    item: NextUpItem(kind: .chore, urgency: .overdue, title: chore.title, detail: detail, status: "Overdue")
                )
            }
        }
        if let missed { all.append(missed) }

        let ordered = all.enumerated().sorted { a, b in
            if a.element.start != b.element.start { return a.element.start < b.element.start }
            if a.element.isEvent != b.element.isEvent { return a.element.isEvent }
            return a.offset < b.offset
        }.map(\.element)

        // Quiet unless something needs a look: on now, missed, or about to start.
        let soon = now.addingTimeInterval(TimeInterval(leadMinutes * 60))
        guard ordered.contains(where: { $0.item.urgency != .soon || $0.start <= soon }) else { return [] }
        return ordered.prefix(maxItems).map(\.item)
    }

    /// "in 27 min" while it is close, "in 2 hr 10 min" up to three hours, then the clock time.
    static func relative(_ start: Date, from now: Date, clock: (Date) -> String) -> String {
        let minutes = max(1, Int((start.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "in \(minutes) min" }
        if minutes < 180 {
            let hours = minutes / 60, rest = minutes % 60
            return rest == 0 ? "in \(hours) hr" : "in \(hours) hr \(rest) min"
        }
        return "at \(clock(start))"
    }
}
