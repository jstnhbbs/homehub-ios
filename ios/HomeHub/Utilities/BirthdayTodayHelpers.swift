import Foundation

/// Working out whose birthday it is today, and how to celebrate it.
enum BirthdayToday {
    /// Birthdays that fall on `today`. This compares dates instead of trusting the server's
    /// "days until", so it stays right when the dashboard was loaded before midnight.
    static func items(_ all: [BirthdayItem], today: String) -> [BirthdayItem] {
        all
            .filter { $0.nextDate == today }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func headline(name: String) -> String {
        "Happy birthday, \(name)!"
    }

    /// "Turning 6 today", or nil when the age is missing or not believable (no birth year).
    static func ageLine(_ age: Int) -> String? {
        guard (1...120).contains(age) else { return nil }
        return "Turning \(age) today"
    }

    /// Confetti plays once per person per day, however often the dashboard refreshes.
    static func hasCelebrated(id: String, localDate: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: storageKey(id)) == localDate
    }

    static func markCelebrated(id: String, localDate: String, defaults: UserDefaults = .standard) {
        defaults.set(localDate, forKey: storageKey(id))
    }

    private static func storageKey(_ id: String) -> String {
        "beacon.birthday.celebrated.\(id)"
    }
}
