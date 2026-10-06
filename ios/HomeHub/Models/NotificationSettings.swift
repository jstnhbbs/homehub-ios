import Foundation

/// What this device reminds the household about, saved locally (never on the server).
struct HomeHubNotificationSettings: Codable, Equatable, Sendable {
    var routinesEnabled: Bool
    var choresEnabled: Bool
    var sleepEnabled: Bool
    var morningRoutineMinute: Int
    var afternoonRoutineMinute: Int
    var eveningRoutineMinute: Int
    var choreMinute: Int
    /// How long before its time a chore that has one reminds. 0 is at the time itself.
    var choreLeadMinutes: Int
    var bedtimeMinute: Int
    var napCheckMinutes: Int
    var birthdaysEnabled: Bool
    var birthdayOnTheDay: Bool
    /// Days of advance notice, chosen from `BirthdayNotificationPlanner.leadDayChoices`.
    var birthdayLeadDays: [Int]
    var birthdayMinute: Int

    static let defaults = HomeHubNotificationSettings(
        routinesEnabled: true,
        choresEnabled: true,
        sleepEnabled: true,
        morningRoutineMinute: 7 * 60,
        afternoonRoutineMinute: 15 * 60,
        eveningRoutineMinute: 19 * 60 + 30,
        choreMinute: 17 * 60,
        choreLeadMinutes: 0,
        bedtimeMinute: 20 * 60,
        napCheckMinutes: 90,
        birthdaysEnabled: true,
        birthdayOnTheDay: true,
        birthdayLeadDays: [7],
        birthdayMinute: BirthdayNotificationPlanner.defaultMinuteOfDay
    )

    var birthdayOptions: BirthdayReminderOptions {
        BirthdayReminderOptions(onTheDay: birthdayOnTheDay, leadDays: birthdayLeadDays, minuteOfDay: birthdayMinute)
    }
}

extension HomeHubNotificationSettings {
    /// Settings saved by an older version are missing the newer fields. Decoding each field
    /// with a fallback keeps the person's existing choices instead of resetting them all.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.defaults
        self.init(
            routinesEnabled: try container.decodeIfPresent(Bool.self, forKey: .routinesEnabled) ?? fallback.routinesEnabled,
            choresEnabled: try container.decodeIfPresent(Bool.self, forKey: .choresEnabled) ?? fallback.choresEnabled,
            sleepEnabled: try container.decodeIfPresent(Bool.self, forKey: .sleepEnabled) ?? fallback.sleepEnabled,
            morningRoutineMinute: try container.decodeIfPresent(Int.self, forKey: .morningRoutineMinute) ?? fallback.morningRoutineMinute,
            afternoonRoutineMinute: try container.decodeIfPresent(Int.self, forKey: .afternoonRoutineMinute) ?? fallback.afternoonRoutineMinute,
            eveningRoutineMinute: try container.decodeIfPresent(Int.self, forKey: .eveningRoutineMinute) ?? fallback.eveningRoutineMinute,
            choreMinute: try container.decodeIfPresent(Int.self, forKey: .choreMinute) ?? fallback.choreMinute,
            choreLeadMinutes: try container.decodeIfPresent(Int.self, forKey: .choreLeadMinutes) ?? fallback.choreLeadMinutes,
            bedtimeMinute: try container.decodeIfPresent(Int.self, forKey: .bedtimeMinute) ?? fallback.bedtimeMinute,
            napCheckMinutes: try container.decodeIfPresent(Int.self, forKey: .napCheckMinutes) ?? fallback.napCheckMinutes,
            birthdaysEnabled: try container.decodeIfPresent(Bool.self, forKey: .birthdaysEnabled) ?? fallback.birthdaysEnabled,
            birthdayOnTheDay: try container.decodeIfPresent(Bool.self, forKey: .birthdayOnTheDay) ?? fallback.birthdayOnTheDay,
            birthdayLeadDays: try container.decodeIfPresent([Int].self, forKey: .birthdayLeadDays) ?? fallback.birthdayLeadDays,
            birthdayMinute: try container.decodeIfPresent(Int.self, forKey: .birthdayMinute) ?? fallback.birthdayMinute
        )
    }
}
