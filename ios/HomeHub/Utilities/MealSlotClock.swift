import Foundation

/// Which meal the Today screen should feature at a given time of day.
///
/// Before 10:30 AM it is breakfast, from 10:30 AM to 2:30 PM lunch, and from 2:30 PM on dinner.
/// Dinner also covers the late evening: there is no meal after it to move on to, and tomorrow's
/// breakfast is not part of today's data.
enum MealSlotClock {
    static let breakfastEndsAtMinute = 10 * 60 + 30
    static let lunchEndsAtMinute = 14 * 60 + 30

    static func slot(minuteOfDay: Int) -> MealSlot {
        if minuteOfDay < breakfastEndsAtMinute { return .breakfast }
        if minuteOfDay < lunchEndsAtMinute { return .lunch }
        return .dinner
    }

    /// The slot at a moment in time, read on the household's clock rather than the device's.
    static func slot(at date: Date, timezone: TimeZone) -> MealSlot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return slot(minuteOfDay: (components.hour ?? 0) * 60 + (components.minute ?? 0))
    }
}
