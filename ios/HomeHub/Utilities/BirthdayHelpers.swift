import Foundation

enum BirthdayHelpers {
    struct BirthdayProfile: Sendable {
        let id: String
        let name: String
        let color: String
        let birthday: String?
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

    static func upcomingBirthdays(
        profiles: [BirthdayProfile],
        today: String,
        withinDays: Int = 14
    ) -> [(profile: BirthdayProfile, localDate: String, daysUntil: Int)] {
        let year = Int(today.prefix(4)) ?? Calendar.current.component(.year, from: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let todayDate = formatter.date(from: today) else { return [] }

        return profiles.compactMap { profile -> (BirthdayProfile, String, Int)? in
            guard let birthday = profile.birthday else { return nil }
            var localDate = birthdayDateInYear(birthday: birthday, year: year)
            if localDate < today {
                localDate = birthdayDateInYear(birthday: birthday, year: year + 1)
            }
            guard let eventDate = formatter.date(from: localDate) else { return nil }
            let daysUntil = Calendar.current.dateComponents([.day], from: todayDate, to: eventDate).day ?? 999
            guard daysUntil <= withinDays else { return nil }
            return (profile, localDate, daysUntil)
        }
        .sorted { $0.2 < $1.2 }
    }
}
