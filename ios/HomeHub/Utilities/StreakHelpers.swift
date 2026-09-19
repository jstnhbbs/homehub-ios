import Foundation

enum StreakHelpers {
    /// Streak lengths that get a celebration.
    static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]

    /// A streak of one day is just "today", so the badge waits until it is worth showing.
    static let minimumToShow = 2

    static func isMilestone(_ days: Int) -> Bool {
        milestones.contains(days)
    }

    static func label(_ days: Int) -> String {
        "\(days)-day streak"
    }

    static func celebrationMessage(name: String, days: Int) -> String {
        "\(name) hit a \(days)-day streak!"
    }

    /// Celebrates each profile at most once per day, even if the dashboard refreshes several times.
    static func hasCelebrated(profileKey: String, localDate: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: storageKey(profileKey)) == localDate
    }

    static func markCelebrated(profileKey: String, localDate: String, defaults: UserDefaults = .standard) {
        defaults.set(localDate, forKey: storageKey(profileKey))
    }

    private static func storageKey(_ profileKey: String) -> String {
        "beacon.streak.celebrated.\(profileKey)"
    }
}
