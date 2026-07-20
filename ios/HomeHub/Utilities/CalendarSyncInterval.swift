import Foundation

struct CalendarSyncIntervalOption: Identifiable, Sendable {
    let minutes: Int
    let label: String
    var id: Int { minutes }
}

enum CalendarSyncInterval {
    static let options: [CalendarSyncIntervalOption] = [
        .init(minutes: 0, label: "Manual only"),
        .init(minutes: 5, label: "Every 5 minutes"),
        .init(minutes: 15, label: "Every 15 minutes"),
        .init(minutes: 30, label: "Every 30 minutes"),
        .init(minutes: 60, label: "Every hour"),
    ]

    static let defaultMinutes = 15

    static func parse(_ value: Int?) -> Int {
        guard let value, options.contains(where: { $0.minutes == value }) else {
            return defaultMinutes
        }
        return value
    }

    static func intervalSeconds(_ minutes: Int) -> TimeInterval {
        TimeInterval(minutes * 60)
    }

    static func cooldownSeconds(_ minutes: Int) -> TimeInterval {
        guard minutes > 0 else { return 0 }
        let interval = intervalSeconds(minutes)
        return max(interval - 60, interval * 0.8)
    }
}
