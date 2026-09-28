import Foundation

/// Small rules for when a dashboard row's second line is worth showing. In both cases the
/// underlying value can be the *same string repeated on every row* — a native reminder's
/// "category" is really just the name of the Reminders list it lives in, and a schedule row's
/// calendar name is the same for every event when there is only one calendar. Repeating a
/// constant on every row adds no information once you have seen it once, at the cost of a whole
/// line per item.
enum DashboardRowHelpers {
    /// What to show under a grocery item's title.
    ///
    /// A real quantity (from a server-tracked item, or one a person eventually types into the
    /// reminder) always wins. Failing that, `category` is only shown when the item is
    /// server-tracked, where it is a genuine per-item categorization ("Produce", "Dairy", ...).
    /// A native-Reminders item's `category` is the Reminders *list's own name* — identical for
    /// every item in the list — so there is nothing useful to show.
    static func grocerySubtitle(quantity: String?, category: String, isServerBacked: Bool) -> String? {
        if let quantity, !quantity.trimmingCharacters(in: .whitespaces).isEmpty {
            return quantity
        }
        return isServerBacked ? category : nil
    }

    /// Whether a schedule row should append its calendar's name. Worth it once the visible
    /// events come from more than one calendar; with a single calendar it is the same string
    /// on every row.
    static func showsCalendarName(_ calendarNames: [String?]) -> Bool {
        Set(calendarNames.compactMap { $0 }).count > 1
    }
}
