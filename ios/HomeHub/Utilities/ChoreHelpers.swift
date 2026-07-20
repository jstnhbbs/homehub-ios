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

    private static let allDays = "0,1,2,3,4,5,6"

    static func weeklyChoreDay(_ days: String) -> String {
        let trimmed = days.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains(",") {
            return trimmed
        }
        return "1"
    }

    static func choreDaysForCadence(cadence: ChoreCadence, weekDay: String?) -> String {
        if cadence == .daily { return allDays }
        guard let weekDay, weekDay.range(of: "^[0-6]$", options: .regularExpression) != nil else {
            return "1"
        }
        return weekDay
    }

    static func weekdayLabel(_ day: String) -> String {
        weekdayOptions.first { $0.value == day }?.label ?? "Monday"
    }

    static func choreCadenceDetail(cadence: ChoreCadence, days: String) -> String {
        if cadence == .daily { return "Every day" }
        return "Once a week · \(weekdayLabel(weeklyChoreDay(days)))"
    }

    static func localDayOfWeek(localDate: String, timezone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let components = localDate.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return 0 }
        var dateComponents = DateComponents()
        dateComponents.year = components[0]
        dateComponents.month = components[1]
        dateComponents.day = components[2]
        dateComponents.hour = 12
        guard let date = calendar.date(from: dateComponents) else { return 0 }
        return calendar.component(.weekday, from: date) - 1
    }

    static func isChoreDueOnDate(
        cadence: ChoreCadence,
        days: String,
        localDate: String,
        timezone: TimeZone
    ) -> Bool {
        if cadence == .daily { return true }
        return weeklyChoreDay(days) == String(localDayOfWeek(localDate: localDate, timezone: timezone))
    }
}
