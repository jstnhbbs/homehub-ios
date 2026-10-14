import ActivityKit
import Foundation

/// Shared by the app (which starts and ends the Live Activity) and the widget extension (which draws
/// it). Keep this file free of app-only types so both targets can compile it.
struct SleepActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the sleep began. The timer counts up from here, so nothing has to be pushed each minute.
        var startedAt: Date
    }

    /// The nap or night log this activity follows. A new log means a new activity.
    var sleepId: String
    var profileId: String
    var childName: String
    var colorHex: String
    /// "nap" or "night".
    var kind: String
}
