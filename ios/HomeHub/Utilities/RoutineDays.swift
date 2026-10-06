import Foundation

/// The weekdays a routine runs on. The server keeps them as "1,3,5" (0 is Sunday).
enum RoutineDays {
    static let everyDay: Set<Int> = Set(0...6)
    static let weekdays: Set<Int> = [1, 2, 3, 4, 5]
    static let weekends: Set<Int> = [0, 6]

    private static let shortNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private static let abbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let fullNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// Reads the stored text. Anything unreadable, or nothing at all, is every day, so an older
    /// routine can never end up running on no days.
    static func parse(_ days: String) -> Set<Int> {
        let chosen = Set(days.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (0...6).contains($0) })
        return chosen.isEmpty ? everyDay : chosen
    }

    static func storage(_ days: Set<Int>) -> String {
        days.sorted().map(String.init).joined(separator: ",")
    }

    /// The seven weekdays starting from the household's first day of the week.
    static func ordered(weekStartsOn: Int) -> [Int] {
        let start = max(0, min(6, weekStartsOn))
        return (0..<7).map { (start + $0) % 7 }
    }

    static func shortName(_ weekday: Int) -> String { shortNames[weekday % 7] }
    static func fullName(_ weekday: Int) -> String { fullNames[weekday % 7] }

    /// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
    static func summary(_ days: Set<Int>) -> String {
        if days == everyDay { return "Every day" }
        if days == weekdays { return "Weekdays" }
        if days == weekends { return "Weekends" }
        // Monday first, as the weekdays are usually listed.
        return ordered(weekStartsOn: 1).filter(days.contains).map { abbreviations[$0] }.joined(separator: ", ")
    }

    static func summary(_ days: String) -> String { summary(parse(days)) }

    /// Whether a routine with these days runs on a calendar date ("YYYY-MM-DD").
    static func runsOn(_ days: String, localDate: String) -> Bool {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return true }
        return parse(days).contains(calendar.component(.weekday, from: date) - 1)
    }
}
