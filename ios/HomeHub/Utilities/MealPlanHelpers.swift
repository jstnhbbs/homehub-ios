import Foundation

/// One slot in the meal plan ("2026-09-18" + dinner). Also the payload for dragging a meal:
/// dragging carries `token`, and a drop target turns it back into a slot with `init(token:)`.
struct MealSlotRef: Hashable, Identifiable, Sendable {
    let localDate: String
    let slot: MealSlot

    var id: String { token }

    static let tokenPrefix = "beacon.meal:"

    var token: String { "\(Self.tokenPrefix)\(localDate):\(slot.rawValue)" }

    init(localDate: String, slot: MealSlot) {
        self.localDate = localDate
        self.slot = slot
    }

    init?(token: String) {
        guard token.hasPrefix(Self.tokenPrefix) else { return nil }
        let parts = token.dropFirst(Self.tokenPrefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 10,
              let slot = MealSlot(rawValue: String(parts[1])) else { return nil }
        self.init(localDate: String(parts[0]), slot: slot)
    }
}

/// A meal worth offering again in the picker.
struct RecentMeal: Identifiable, Equatable, Sendable {
    let title: String
    let recipeId: String?

    var id: String { recipeId ?? "title:" + title.lowercased() }
}

extension MealSlot {
    /// The slots shown in the weekly plan. Snacks have their own screen.
    static let planningSlots: [MealSlot] = [.breakfast, .lunch, .dinner]
}

enum MealPlanHelpers {
    /// Same cleanup the server applies: trim every line and drop blank ones.
    static func normalizedTitle(_ raw: String) -> String {
        raw.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Shifts a `yyyy-MM-dd` date by whole days in the household's time zone.
    static func date(_ localDate: String, adding days: Int, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let start = DateHelpers.dateFromLocalDate(localDate, timezone: timezone),
              let shifted = calendar.date(byAdding: .day, value: days, to: start) else {
            return localDate
        }
        return DateHelpers.localDateIn(timezone: timezone, date: shifted)
    }

    /// "Sep 14 – 20", "Sep 28 – Oct 4", or with a year when the week is not in the current year.
    static func weekRangeLabel(first: String, last: String, timezone: TimeZone, now: Date = .now) -> String {
        guard let start = DateHelpers.dateFromLocalDate(first, timezone: timezone),
              let end = DateHelpers.dateFromLocalDate(last, timezone: timezone) else {
            return "\(first) – \(last)"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
            && calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let currentYear = calendar.component(.year, from: now)
        let showsYear = calendar.component(.year, from: start) != currentYear
            || calendar.component(.year, from: end) != currentYear

        func format(_ date: Date, _ pattern: String) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timezone
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }

        let left = format(start, "MMM d")
        let right = sameMonth ? format(end, "d") : format(end, "MMM d")
        return showsYear ? "\(left) – \(right), \(format(end, "yyyy"))" : "\(left) – \(right)"
    }

    /// Most recently planned meals first, one entry per recipe (or per title for custom meals).
    /// Snacks are left out.
    static func recentMeals(from meals: [Meal], limit: Int = 10) -> [RecentMeal] {
        let slotOrder: [MealSlot: Int] = [.dinner: 3, .lunch: 2, .breakfast: 1, .snack: 0]
        let ordered = meals
            .filter { $0.slot != .snack && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { lhs, rhs in
                if lhs.localDate != rhs.localDate { return lhs.localDate > rhs.localDate }
                return slotOrder[lhs.slot, default: 0] > slotOrder[rhs.slot, default: 0]
            }

        var seen = Set<String>()
        var result: [RecentMeal] = []
        for meal in ordered {
            let recent = RecentMeal(title: meal.title, recipeId: meal.recipeId)
            guard seen.insert(recent.id).inserted else { continue }
            result.append(recent)
            if result.count == limit { break }
        }
        return result
    }
}
