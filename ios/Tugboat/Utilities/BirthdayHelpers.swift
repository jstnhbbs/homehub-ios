import Foundation
import CoreGraphics

enum BirthdayHelpers {
    struct BirthdayProfile: Sendable {
        let id: String
        let name: String
        let color: String
        let birthday: String?
    }

    struct RingMark: Identifiable, Sendable {
        let id: String
        let name: String
        let color: String
        let avatar: String?
        let angle: Double
        let extra: Int
        let isNext: Bool
        /// Everyone sharing this spot on the ring, lead first, so a person hidden behind the lead
        /// can still be featured and highlighted.
        let memberIds: [String]
        let x: CGFloat
        let y: CGFloat
    }

    static func birthdayDate(from localDate: String, timezone: TimeZone) -> Date? {
        CalendarHelpers.parseLocalDate(localDate, timezone: timezone)
    }

    static func localBirthday(from date: Date, timezone: TimeZone) -> String {
        DateHelpers.localDateIn(timezone: timezone, date: date)
    }

    static func maxBirthdayDate(timezone: TimeZone) -> Date {
        let today = DateHelpers.localDateIn(timezone: timezone)
        return birthdayDate(from: today, timezone: timezone) ?? .now
    }

    static func birthdayDateInYear(birthday: String, year: Int) -> String {
        let monthDay = String(birthday.dropFirst(5))
        let date = "\(year)-\(monthDay)"
        let parts = monthDay.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return "\(year)-02-28" }

        var components = DateComponents()
        components.year = year
        components.month = parts[0]
        components.day = parts[1]
        let calendar = Calendar(identifier: .gregorian)
        if calendar.date(from: components) != nil {
            return date
        }
        return "\(year)-02-28"
    }

    static func nextOccurrence(birthDate: String, today: String) -> (localDate: String, daysUntil: Int, upcomingAge: Int) {
        let year = Int(today.prefix(4)) ?? Calendar.current.component(.year, from: .now)
        var localDate = birthdayDateInYear(birthday: birthDate, year: year)
        if localDate < today {
            localDate = birthdayDateInYear(birthday: birthDate, year: year + 1)
        }
        let daysUntil = daysBetween(from: today, to: localDate)
        let upcomingAge = (Int(localDate.prefix(4)) ?? year) - (Int(birthDate.prefix(4)) ?? year)
        return (localDate, daysUntil, upcomingAge)
    }

    static func daysBetween(from today: String, to localDate: String) -> Int {
        let timezone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard
            let start = DateHelpers.dateFromLocalDate(today, timezone: timezone),
            let end = DateHelpers.dateFromLocalDate(localDate, timezone: timezone)
        else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func upcomingBirthdays(
        profiles: [BirthdayProfile],
        today: String,
        withinDays: Int = 14
    ) -> [(profile: BirthdayProfile, localDate: String, daysUntil: Int)] {
        profiles.compactMap { profile -> (BirthdayProfile, String, Int)? in
            guard let birthday = profile.birthday else { return nil }
            let next = nextOccurrence(birthDate: birthday, today: today)
            guard next.daysUntil <= withinDays else { return nil }
            return (profile, next.localDate, next.daysUntil)
        }
        .sorted { $0.2 < $1.2 }
    }

    static func monthIndex(from localDate: String) -> Int? {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return parts[1] - 1
    }

    static func monthTitle(index: Int, timezone: TimeZone) -> String {
        let symbols = Calendar.autoupdatingCurrent.monthSymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    static func monthShortTitle(index: Int, timezone: TimeZone) -> String {
        let symbols = Calendar.autoupdatingCurrent.shortMonthSymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    static func monthGroups(from items: [BirthdayItem], timezone: TimeZone, today: String) -> [BirthdayMonthGroup] {
        var buckets: [Int: [BirthdayItem]] = [:]
        for item in items {
            guard let month = monthIndex(from: item.nextDate) else { continue }
            buckets[month, default: []].append(item)
        }
        return buckets
            .sorted { lhs, rhs in
                let lhsSoonest = lhs.value.map(\.daysUntil).min() ?? Int.max
                let rhsSoonest = rhs.value.map(\.daysUntil).min() ?? Int.max
                return lhsSoonest == rhsSoonest ? lhs.key < rhs.key : lhsSoonest < rhsSoonest
            }
            .map { month, grouped in
            let sortedItems = grouped.sorted {
                $0.daysUntil == $1.daysUntil ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : $0.daysUntil < $1.daysUntil
            }
            return BirthdayMonthGroup(
                id: month,
                month: month,
                title: monthTitle(index: month, timezone: timezone),
                items: sortedItems
            )
        }
    }

    static func countdownLabel(daysUntil: Int) -> String {
        switch daysUntil {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "\(daysUntil) days"
        }
    }

    static func dateLabel(_ localDate: String, timezone: TimeZone, includeYear: Bool = false) -> String {
        DateHelpers.formatLocalDate(
            localDate,
            timezone: timezone,
            pattern: includeYear ? "MMM d, yyyy" : "MMM d"
        )
    }

    static func dayOfYear(localDate: String) -> Int {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 1 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = calendar.date(from: components) else { return 1 }
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    static func daysInYear(_ year: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        guard let date = calendar.date(from: components) else { return 365 }
        return calendar.ordinality(of: .day, in: .year, for: date) ?? 365
    }

    static func angle(forDayOfYear day: Int, daysInYear: Int) -> Double {
        (Double(day) / Double(daysInYear)) * 360 - 90
    }

    static func point(angleDegrees: Double, radius: CGFloat, center: CGFloat) -> CGPoint {
        let radians = angleDegrees * .pi / 180
        return CGPoint(
            x: center + radius * CGFloat(cos(radians)),
            y: center + radius * CGFloat(sin(radians))
        )
    }

    /// Which of a crowded spot's people is drawn on the ring. Someone with a profile in the app
    /// comes first (a manually added person is often a relative or friend, and the family's own
    /// members are who the ring is for). Among those, or among everyone when nobody has a profile,
    /// the soonest upcoming birthday wins.
    static func ringLeadIndex(isProfile: [Bool], daysUntil: [Int]) -> Int {
        guard !isProfile.isEmpty else { return 0 }
        let indices = Array(isProfile.indices)
        let profiles = indices.filter { isProfile[$0] }
        let pool = profiles.isEmpty ? indices : profiles
        return pool.min { daysUntil[$0] < daysUntil[$1] } ?? pool[0]
    }

    static func ringMarks(
        items: [BirthdayItem],
        today: String,
        size: CGFloat,
        ringInset: CGFloat = 46,
        avatarRadius: CGFloat = 13
    ) -> [RingMark] {
        let year = Int(today.prefix(4)) ?? Calendar.current.component(.year, from: .now)
        let days = daysInYear(year)
        let center = size / 2
        let ringRadius = size / 2 - ringInset
        let nextId = items.min(by: { $0.daysUntil < $1.daysUntil })?.id

        let placed = items
            .map { item -> (item: BirthdayItem, angle: Double) in
                let occurrence = birthdayDateInYear(birthday: item.birthDate, year: year)
                return (item, angle(forDayOfYear: dayOfYear(localDate: occurrence), daysInYear: days))
            }
            .sorted { $0.angle < $1.angle }

        let minSeparation =
            (2 * asin(min(1.0, Double(avatarRadius + 2) / Double(ringRadius))) * 180) / .pi
        var clusters: [[(item: BirthdayItem, angle: Double)]] = []
        for entry in placed {
            if let current = clusters.last, entry.angle - current[0].angle < minSeparation {
                clusters[clusters.count - 1].append(entry)
            } else {
                clusters.append([entry])
            }
        }

        if clusters.count > 1, let first = clusters.first, let last = clusters.last {
            if 360 - last[0].angle + first[0].angle < minSeparation {
                clusters[0].insert(contentsOf: last, at: 0)
                clusters.removeLast()
            }
        }

        return clusters.map { group in
            let leadIndex = ringLeadIndex(
                isProfile: group.map { $0.item.source == .profile && $0.item.kind == .birthday },
                daysUntil: group.map { $0.item.daysUntil }
            )
            let lead = group[leadIndex].item
            let angle = group[0].angle
            let point = point(angleDegrees: angle, radius: ringRadius, center: center)
            return RingMark(
                id: lead.id,
                name: lead.name,
                color: lead.color,
                avatar: lead.avatar,
                angle: angle,
                extra: group.count - 1,
                isNext: lead.id == nextId,
                memberIds: ([lead] + group.map(\.item).filter { $0.id != lead.id }).map(\.id),
                x: point.x,
                y: point.y
            )
        }
    }
}
