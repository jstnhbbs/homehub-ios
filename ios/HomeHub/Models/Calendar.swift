import Foundation

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month

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
    var accountName: String = ""

    static func groupedByAccount(
        _ calendars: [CalendarPickerOption]
    ) -> [(account: String, calendars: [CalendarPickerOption])] {
        Dictionary(grouping: calendars, by: \.accountName)
            .map { (account: $0.key, calendars: $0.value) }
            .sorted {
                $0.account.localizedCaseInsensitiveCompare($1.account) == .orderedAscending
            }
    }
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

enum NativeCalendarAccessStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var settingsLabel: String {
        switch self {
        case .authorized: "Allowed"
        case .notDetermined: "Not Asked"
        case .denied: "Denied"
        case .restricted: "Restricted"
        }
    }
}

enum NativeNewItemKind: String, CaseIterable, Identifiable {
    case event
    case reminder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .event: "Event"
        case .reminder: "Reminder"
        }
    }
}

enum NativeAlertOffset: Int, CaseIterable, Identifiable {
    case none = -1
    case atTime = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .atTime: "At Time"
        case .fiveMinutes: "5 Minutes Before"
        case .fifteenMinutes: "15 Minutes Before"
        case .thirtyMinutes: "30 Minutes Before"
        case .oneHour: "1 Hour Before"
        case .oneDay: "1 Day Before"
        }
    }
}

enum NativeCalendarPreferenceKeys {
    static let defaultCalendarId = "beacon.nativeCalendar.defaultCalendarId"
    static let defaultNewItem = "beacon.nativeCalendar.defaultNewItem"
    static let eventAlert = "beacon.nativeCalendar.eventAlertMinutes"
    static let reminderAlert = "beacon.nativeCalendar.reminderAlertMinutes"
    static let agendaFontSize = "beacon.nativeCalendar.agendaFontSize"
    static let useSystemAgendaFont = "beacon.nativeCalendar.useSystemAgendaFont"
    static let automaticId = "automatic"
}

struct UpdateCalendarSettingsRequest: Codable, Sendable {
    var weekStartsOn: Int?
}
