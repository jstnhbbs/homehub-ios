import Foundation

struct WeekStartOption: Identifiable, Sendable {
    let value: Int
    let label: String
    var id: Int { value }
}

enum WeekStart {
    static let options: [WeekStartOption] = [
        .init(value: 0, label: "Sunday"),
        .init(value: 1, label: "Monday"),
        .init(value: 2, label: "Tuesday"),
        .init(value: 3, label: "Wednesday"),
        .init(value: 4, label: "Thursday"),
        .init(value: 5, label: "Friday"),
        .init(value: 6, label: "Saturday"),
    ]

    static let defaultWeekStartsOn = 1

    static func parseWeekStartsOn(_ value: Int?) -> Int {
        guard let value, options.contains(where: { $0.value == value }) else {
            return defaultWeekStartsOn
        }
        return value
    }

    static func weekdayLabels(weekStartsOn: Int) -> [String] {
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let start = max(0, min(6, weekStartsOn))
        return Array(labels[start...]) + Array(labels[..<start])
    }
}
