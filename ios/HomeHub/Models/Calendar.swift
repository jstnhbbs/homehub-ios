import Foundation

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month
    case week
    case day

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month: "Month"
        case .week: "Week"
        case .day: "Day"
        }
    }
}

struct CalendarPickerOption: Codable, Identifiable, Sendable {
    let id: String
    var displayName: String
    var color: String
    var provider: CalendarProvider
}

struct CalendarOccurrence: Codable, Identifiable, Sendable {
    var id: String { "\(eventId)-\(startsAt.timeIntervalSince1970)" }
    let eventId: String
    var calendarId: String?
    var title: String
    var description: String?
    var location: String?
    var startsAt: Date
    var endsAt: Date
    var allDay: Bool
    var color: String
    var calendarName: String
    var provider: CalendarProvider?
    var isBirthday: Bool
    var profileId: String?
}

struct CalendarEventFormInput: Codable, Sendable {
    var calendarId: String
    var title: String
    var startsAt: String
    var endsAt: String
    var allDay: Bool
    var location: String?
    var description: String?
}

struct CalendarConnection: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var provider: CalendarProvider
    var accountEmail: String
    var appleId: String?
    var status: CalendarConnectionStatus
    var errorMessage: String?
    var lastSyncedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

struct HouseholdCalendar: Codable, Identifiable, Sendable {
    let id: String
    let connectionId: String
    var url: String
    var displayName: String
    var color: String
    var enabled: Bool
}

struct ScheduleEvent: Codable, Identifiable, Sendable {
    var id: String { eventId }
    let eventId: String
    var title: String
    var startsAt: Date
    var endsAt: Date
    var allDay: Bool
    var color: String?
    var calendarName: String?
}

struct CalendarSyncStatus: Codable, Sendable {
    var connected: Bool
    var updatedLabel: String?
    var lastSyncedAt: Date?
}

struct ConnectICloudRequest: Codable, Sendable {
    var username: String
    var password: String
}

struct UpdateCalendarSelectionRequest: Codable, Sendable {
    var calendarIds: [String]
}

struct UpdateCalendarSettingsRequest: Codable, Sendable {
    var weekStartsOn: Int?
    var calendarSyncIntervalMinutes: Int?
}

struct HouseholdCalendarOption: Codable, Identifiable, Sendable {
    let id: String
    let connectionId: String
    var displayName: String
    var color: String
    var enabled: Bool
    var provider: CalendarProvider
}

struct GoogleConnectURLResponse: Codable, Sendable {
    let url: String
}

struct OkResponse: Codable, Sendable {
    let ok: Bool
}
