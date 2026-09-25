import Foundation

/// Wording and icons that differ between a birthday and an anniversary.
extension CelebrationKind {
    var noun: String {
        switch self {
        case .birthday: "birthday"
        case .anniversary: "anniversary"
        }
    }

    var capitalizedNoun: String {
        noun.prefix(1).uppercased() + noun.dropFirst()
    }

    var systemImage: String {
        switch self {
        case .birthday: "gift.fill"
        case .anniversary: "heart.fill"
        }
    }

    /// "turns 6" for a birthday, "10 years" for an anniversary; nil when the number is not usable.
    func ageDetail(_ number: Int) -> String? {
        guard (1...120).contains(number) else { return nil }
        switch self {
        case .birthday: return "turns \(number)"
        case .anniversary: return number == 1 ? "1 year" : "\(number) years"
        }
    }
}

/// What the module is called. It reads "Birthdays" until the household has an anniversary, and
/// "Celebrations" once it does. The answer comes from the server (any entry of that kind, not just
/// ones coming up soon) and is remembered on the device so the very first screen already uses it.
enum CelebrationNaming {
    static let birthdaysTitle = "Birthdays"
    static let celebrationsTitle = "Celebrations"

    private static let storageKey = "beacon.celebrations.hasAnniversaries"

    static func title(hasAnniversaries: Bool) -> String {
        hasAnniversaries ? celebrationsTitle : birthdaysTitle
    }

    static func remindersTitle(hasAnniversaries: Bool) -> String {
        hasAnniversaries ? "Celebration Reminders" : "Birthday Reminders"
    }

    static func hasAnniversaries(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func setHasAnniversaries(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: storageKey)
    }

    /// The name to show right now.
    static var current: String {
        title(hasAnniversaries: hasAnniversaries())
    }

    static var currentRemindersTitle: String {
        remindersTitle(hasAnniversaries: hasAnniversaries())
    }
}
