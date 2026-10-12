import Foundation

/// A day in the Large Food card's list: its date, and the dinner planned for it (nil if none).
struct FoodDay: Identifiable {
    let date: String
    let dinner: Meal?
    var id: String { date }
}

/// What the Food card says: tonight's dinner for Small, and for Large the days after today (to the end of
/// the household's week, or all of next week when today is the last day of it) with their dinners.
struct FoodCardSummary {
    let todayDate: String
    let timezone: TimeZone
    /// 0 is Sunday, as the household setting stores it.
    let weekStartsOn: Int
    let today: [Meal]
    /// Dinners planned for the coming days; days with none are simply missing.
    let upcomingDinners: [Meal]

    var dinner: Meal? { today.first { $0.slot == .dinner } }

    /// A meal's first line (the dish); the rest are sides and notes.
    static func dish(_ meal: Meal?) -> String? {
        DashboardHelpers.mealLines(meal?.title ?? "").first
    }

    /// The big words on a Small card: tonight's dish, or that it is not planned.
    var headline: String { Self.dish(dinner) ?? "Not planned" }
    var caption: String { "Dinner tonight" }

    /// Today's meals for a Medium card, which can show only a couple: the ones still ahead first, then the
    /// ones that are over (breakfast is over by 10, lunch by 2 in the afternoon, dinner by 9 at night), each
    /// group in the order of the day. At night that puts dinner ahead of breakfast.
    static func slotsByRelevance(hour: Int) -> [MealSlot] {
        let overHour: [MealSlot: Int] = [.breakfast: 10, .lunch: 14, .dinner: 21]
        let slots: [MealSlot] = [.breakfast, .lunch, .dinner]
        let ahead = slots.filter { hour < (overHour[$0] ?? 24) }
        return ahead + slots.filter { !ahead.contains($0) }
    }

    /// The one line above a Medium or Large card's rows.
    var line: String {
        let day = DateHelpers.formatLocalDate(todayDate, timezone: timezone, pattern: "EEEE")
        return "Today · \(day)"
    }

    private func date(byAdding days: Int, to localDate: String) -> String? {
        guard let start = DateHelpers.dateFromLocalDate(localDate, timezone: timezone),
              let moved = DateHelpers.gregorian(in: timezone).date(byAdding: .day, value: days, to: start) else { return nil }
        return DateHelpers.localDateIn(timezone: timezone, date: moved)
    }

    /// How many days after today are left in the household's week (0 when today is the last).
    var daysLeftInWeek: Int {
        guard let start = DateHelpers.dateFromLocalDate(todayDate, timezone: timezone) else { return 0 }
        let weekday = DateHelpers.gregorian(in: timezone).component(.weekday, from: start) - 1 // 0 = Sunday
        let offset = (weekday - weekStartsOn + 7) % 7
        return 6 - offset
    }

    /// The heading over the list: what the days after today are.
    var restTitle: String { daysLeftInWeek == 0 ? "Next week" : "Rest of the week" }

    /// Each remaining day of the week with its dinner. On the last day of the week it is the next seven days.
    var rest: [FoodDay] {
        let count = daysLeftInWeek == 0 ? 7 : daysLeftInWeek
        return (1...count).compactMap { offset in
            guard let day = date(byAdding: offset, to: todayDate) else { return nil }
            return FoodDay(date: day, dinner: upcomingDinners.first { $0.localDate == day })
        }
    }

    /// The short weekday ("Mon") for a day in `rest`.
    func weekday(_ day: FoodDay) -> String {
        DateHelpers.formatLocalDate(day.date, timezone: timezone, pattern: "EEE")
    }
}
