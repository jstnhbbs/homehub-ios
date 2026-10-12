import Foundation

/// What the Chores card says at each size, worked out from the dashboard's chores so the wording and
/// the order are the same on iPhone and iPad and can be checked without a screen.
///
/// `today` is the dashboard's list of chores due today (done and not done); `later` is the ones that
/// come round again within the week, each with the day it next falls on.
struct ChoreCardSummary {
    let today: [ChoreRow]
    let later: [ChoreRow]
    /// Today's date in the household's time zone ("YYYY-MM-DD"), which `later`'s days are counted from.
    let todayDate: String
    let timezone: TimeZone

    var total: Int { today.count }
    var doneCount: Int { today.filter(\.completed).count }

    /// What is still to do, the most pressing first: late ones, then ones with a time (earliest first),
    /// then the rest in the order they were given.
    var pending: [ChoreRow] {
        let open = today.filter { !$0.completed }
        func rank(_ chore: ChoreRow) -> Int {
            if chore.overdue == true { return 0 }
            return chore.dueTime == nil ? 2 : 1
        }
        return open.enumerated().sorted { a, b in
            let (ra, rb) = (rank(a.element), rank(b.element))
            if ra != rb { return ra < rb }
            if ra < 2, let ta = a.element.dueTime, let tb = b.element.dueTime, ta != tb { return ta < tb }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// The big words on a Small card.
    var headline: String {
        if total == 0 { return "None today" }
        let left = pending.count
        return left == 0 ? "All done" : "\(left) left"
    }

    /// The one line a Medium or Large card puts above its rows.
    var line: String {
        if total == 0 { return "Nothing due today" }
        let left = pending.count
        if left == 0 { return total == 1 ? "1 chore done" : "All \(total) done" }
        return doneCount > 0 ? "\(left) left · \(doneCount) done" : "\(left) left"
    }

    /// The line under a Small card's headline: what is next, or what is coming if today is clear.
    var caption: String {
        if let next = pending.first {
            let label = next.dueTime.map { ChoreHelpers.timeLabel($0) }
            if next.overdue == true { return "Overdue: \(next.title)" }
            return label.map { "Next: \(next.title) · \($0)" } ?? "Next: \(next.title)"
        }
        if let soon = later.first {
            return "Next: \(soon.title) · \(dayLabel(for: soon))"
        }
        return total == 0 ? "Nothing scheduled" : "Nice work"
    }

    /// How far through today's chores the family is, for a progress bar; nil when there are none.
    var progress: Double? {
        total == 0 ? nil : Double(doneCount) / Double(total)
    }

    /// True when a chore in `later` next falls tomorrow.
    func isTomorrow(_ chore: ChoreRow) -> Bool {
        guard let day = chore.nextDueDate,
              let from = DateHelpers.dateFromLocalDate(todayDate, timezone: timezone),
              let to = DateHelpers.dateFromLocalDate(day, timezone: timezone) else { return false }
        return DateHelpers.gregorian(in: timezone).dateComponents([.day], from: from, to: to).day == 1
    }

    /// The short weekday ("Sat") a chore in `later` next falls on, for its chip.
    func weekdayLabel(for chore: ChoreRow) -> String {
        guard let day = chore.nextDueDate else { return "Soon" }
        return DateHelpers.formatLocalDate(day, timezone: timezone, pattern: "EEE")
    }

    /// "Tomorrow", or the short weekday ("Sat"), for a chore in `later`.
    func dayLabel(for chore: ChoreRow) -> String {
        chore.nextDueDate == nil ? "Soon" : (isTomorrow(chore) ? "Tomorrow" : weekdayLabel(for: chore))
    }

    /// A coming-up row's second line: who it is for when that varies, then the time if it has one. The
    /// day is the row's chip, not part of this line. Nil when there is nothing to say.
    func laterSubtitle(for chore: ChoreRow, assignee: String?) -> String? {
        var parts: [String] = []
        if let assignee { parts.append(assignee) }
        if let time = chore.dueTime { parts.append(ChoreHelpers.timeLabel(time)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A person's name as a row shows it: the first name, so it fits beside a dot in a narrow row, unless
    /// someone else in `names` has the same first name, in which case the whole name.
    static func shortName(_ name: String, among names: [String]) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        let sharing = Set(names.filter { $0.split(separator: " ").first.map(String.init) == first })
        return sharing.count > 1 ? name : first
    }
}
