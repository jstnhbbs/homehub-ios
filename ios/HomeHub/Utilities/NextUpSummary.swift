import Foundation

/// The banner at the top of Today on iPhone: the next thing with a time on it, across everything.
struct NextUpItem: Equatable {
    enum Kind { case event, chore }

    let kind: Kind
    /// "NOW", "NEXT · 4:00 PM", "DUE · 7:30 PM" or "OVERDUE · 8:00 AM".
    let eyebrow: String
    let title: String
    /// Whose it is, which calendar it is on, or when it ends.
    let detail: String
}

enum NextUpSummary {
    /// Today's calendar events and timed chores, whichever comes next. An event that is on now comes first,
    /// then whatever starts soonest (an event before a chore at the same time). With nothing still to come,
    /// the earliest chore whose time has passed without being done, so it isn't forgotten; with nothing at
    /// all, nil, and the banner goes away. All-day events and chores with no time are left out: they have no
    /// "next". `chores` and `events` are empty when that part of Today is switched off.
    static func next(
        chores: [ChoreRow],
        events: [ScheduleEvent],
        profiles: [Profile],
        todayDate: String,
        timezone: TimeZone,
        now: Date
    ) -> NextUpItem? {
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
        func person(_ chore: ChoreRow) -> String {
            profiles.first { $0.id == chore.profileId }?.name ?? "Anyone"
        }

        var coming: [Candidate] = []
        for event in events where !event.allDay && event.endsAt > now {
            let isOn = event.startsAt <= now
            coming.append(Candidate(
                start: event.startsAt,
                isEvent: true,
                item: NextUpItem(
                    kind: .event,
                    eyebrow: isOn ? "NOW" : "NEXT · \(time(event.startsAt))",
                    title: event.title,
                    detail: isOn ? "Until \(time(event.endsAt))" : (event.calendarName ?? "Calendar")
                )
            ))
        }
        var overdue: [Candidate] = []
        for chore in chores where !chore.completed {
            guard let start = choreStart(chore) else { continue }
            if start >= now {
                coming.append(Candidate(
                    start: start,
                    isEvent: false,
                    item: NextUpItem(kind: .chore, eyebrow: "DUE · \(time(start))", title: chore.title, detail: person(chore))
                ))
            } else {
                overdue.append(Candidate(
                    start: start,
                    isEvent: false,
                    item: NextUpItem(kind: .chore, eyebrow: "OVERDUE · \(time(start))", title: chore.title, detail: person(chore))
                ))
            }
        }

        let first = coming.enumerated().min { a, b in
            if a.element.start != b.element.start { return a.element.start < b.element.start }
            if a.element.isEvent != b.element.isEvent { return a.element.isEvent }
            return a.offset < b.offset
        }?.element
        if let first { return first.item }
        return overdue.min { $0.start < $1.start }?.item
    }
}
