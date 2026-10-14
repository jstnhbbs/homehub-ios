import Foundation

/// A line in the Large Celebrations card's columns: a month's heading or a celebration.
enum CelebrationEntry: Identifiable {
    case header(String)
    case item(BirthdayItem)

    var id: String {
        switch self {
        case .header(let month): "header-\(month)"
        case .item(let item): item.id
        }
    }

    var isItem: Bool {
        if case .item = self { return true }
        return false
    }
}

/// What the Celebrations card says at each size.
struct CelebrationCardSummary {
    /// Everything coming up, soonest first.
    let items: [BirthdayItem]
    /// Today's date in the household's time zone ("YYYY-MM-DD").
    let todayDate: String
    let timezone: TimeZone

    var next: BirthdayItem? { items.first }

    /// How old they turn, or how many years an anniversary marks, as a short phrase ("turns 5", "9 years").
    static func ageText(_ item: BirthdayItem) -> String? {
        guard (1...120).contains(item.upcomingAge) else { return nil }
        switch item.kind {
        case .birthday: return "turns \(item.upcomingAge)"
        case .anniversary: return item.upcomingAge == 1 ? "1 year" : "\(item.upcomingAge) years"
        }
    }

    /// The big words on a Small card: how long to wait for the next one.
    var headline: String {
        guard let next else { return "None soon" }
        return BirthdayHelpers.countdownLabel(daysUntil: next.daysUntil)
    }

    /// The line under it: who, and how old.
    var caption: String {
        guard let next else { return "Add a birthday or anniversary" }
        if let age = Self.ageText(next) { return "\(next.name) · \(age)" }
        return next.name
    }

    /// The one line above a Medium or Large card's rows.
    var line: String {
        if items.isEmpty { return "Nothing coming up" }
        let today = items.filter { $0.nextDate == todayDate }.count
        if today > 0 { return today == 1 ? "1 today" : "\(today) today" }
        let soon = items.filter { $0.daysUntil <= 30 }.count
        return soon == 0 ? "None in the next 30 days" : (soon == 1 ? "1 in the next 30 days" : "\(soon) in the next 30 days")
    }

    /// The month a celebration falls in ("October", or "January 2027" when it is not this year).
    func monthLabel(_ item: BirthdayItem) -> String {
        let year = String(todayDate.prefix(4))
        let sameYear = item.nextDate.hasPrefix(year)
        return DateHelpers.formatLocalDate(item.nextDate, timezone: timezone, pattern: sameYear ? "MMMM" : "MMMM yyyy")
    }

    /// The list as the Large card reads it: under a heading for each month.
    var entries: [CelebrationEntry] {
        var result: [CelebrationEntry] = []
        var current: String?
        for item in items {
            let month = monthLabel(item)
            if month != current {
                result.append(.header(month))
                current = month
            }
            result.append(.item(item))
        }
        return result
    }
}
