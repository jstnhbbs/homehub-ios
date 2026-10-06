import Foundation

struct ChoreWeekdayOption: Identifiable, Sendable {
    let value: String
    let label: String
    var id: String { value }
}

enum ChoreHelpers {
    static let weekdayOptions: [ChoreWeekdayOption] = [
        .init(value: "1", label: "Monday"),
        .init(value: "2", label: "Tuesday"),
        .init(value: "3", label: "Wednesday"),
        .init(value: "4", label: "Thursday"),
        .init(value: "5", label: "Friday"),
        .init(value: "6", label: "Saturday"),
        .init(value: "0", label: "Sunday"),
    ]

    static func weeklyChoreDay(_ days: String) -> String {
        let trimmed = days.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains(",") {
            return trimmed
        }
        return "1"
    }

    static func weekdayLabel(_ day: String) -> String {
        weekdayOptions.first { $0.value == day }?.label ?? "Monday"
    }

    static func choreCadenceDetail(cadence: ChoreCadence, days: String) -> String {
        if cadence == .daily { return "Every day" }
        return "Once a week · \(weekdayLabel(weeklyChoreDay(days)))"
    }
}
