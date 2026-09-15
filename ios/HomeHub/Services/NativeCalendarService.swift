import EventKit
import Foundation
import UIKit

@MainActor
final class NativeCalendarService: ObservableObject {
    @Published private(set) var accessStatus: NativeCalendarAccessStatus
    @Published private(set) var selectedCalendarIds: Set<String>
    @Published private(set) var hasSavedCalendarSelection: Bool
    @Published var defaultCalendarId: String {
        didSet {
            defaults.set(defaultCalendarId, forKey: NativeCalendarPreferenceKeys.defaultCalendarId)
        }
    }

    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard
    private static let selectedCalendarIdsKey = "beacon.nativeCalendar.selectedCalendarIds"

    init() {
        self.accessStatus = Self.currentAccessStatus()
        if let savedIds = UserDefaults.standard.array(forKey: Self.selectedCalendarIdsKey) as? [String] {
            self.selectedCalendarIds = Set(savedIds)
            self.hasSavedCalendarSelection = true
        } else {
            self.selectedCalendarIds = []
            self.hasSavedCalendarSelection = false
        }
        let savedDefault = UserDefaults.standard.string(forKey: NativeCalendarPreferenceKeys.defaultCalendarId)
        self.defaultCalendarId = savedDefault?.isEmpty == false ? savedDefault! : NativeCalendarPreferenceKeys.automaticId
    }

    var usesAutomaticDefaultCalendar: Bool {
        defaultCalendarId == NativeCalendarPreferenceKeys.automaticId || defaultCalendarId.isEmpty
    }

    var defaultCalendarForNewEvents: EKCalendar? {
        if !usesAutomaticDefaultCalendar,
           let calendar = eventStore.calendar(withIdentifier: defaultCalendarId),
           calendar.allowsContentModifications {
            return calendar
        }
        return eventStore.defaultCalendarForNewEvents
    }

    func writablePickerOptions() -> [CalendarPickerOption] {
        pickerOptions().filter { option in
            eventStore.calendar(withIdentifier: option.id)?.allowsContentModifications == true
        }
    }

    var hasFullAccess: Bool {
        accessStatus == .authorized
    }

    func refreshAccessStatus() {
        accessStatus = Self.currentAccessStatus()
    }

    func resetCachedData() {
        eventStore.reset()
        refreshAccessStatus()
    }

    func saveSelectedCalendarIds(_ ids: Set<String>) {
        let accessibleIds = Set(accessibleCalendars().map(\.calendarIdentifier))
        selectedCalendarIds = ids.intersection(accessibleIds)
        hasSavedCalendarSelection = true
        defaults.set(Array(selectedCalendarIds).sorted(), forKey: Self.selectedCalendarIdsKey)
    }

    func selectAllCalendars() {
        saveSelectedCalendarIds(Set(accessibleCalendars().map(\.calendarIdentifier)))
    }

    func effectiveSelectedCalendarIds() -> Set<String> {
        let accessibleIds = Set(accessibleCalendars().map(\.calendarIdentifier))
        guard hasSavedCalendarSelection else { return accessibleIds }
        return selectedCalendarIds.intersection(accessibleIds)
    }

    func requestFullAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            accessStatus = granted ? .authorized : Self.currentAccessStatus()
            if granted {
                eventStore.reset()
            }
        } catch {
            accessStatus = Self.currentAccessStatus()
        }
    }

    func occurrences(start: Date, end: Date, query: String = "") -> [CalendarOccurrence] {
        guard hasFullAccess else { return [] }
        let calendars = selectedCalendars()
        if calendars?.isEmpty == true {
            return []
        }
        let events = eventStore.events(
            matching: eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        )
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return events
            .filter { event in
                guard !normalizedQuery.isEmpty else { return true }
                return "\(event.title ?? "") \(event.location ?? "") \(event.calendar.title)".lowercased().contains(normalizedQuery)
            }
            .map(Self.occurrence)
            .sorted { $0.startsAt < $1.startsAt }
    }

    func pickerOptions() -> [CalendarPickerOption] {
        guard hasFullAccess else { return [] }
        return accessibleCalendars()
            .map { calendar in
                CalendarPickerOption(
                    id: calendar.calendarIdentifier,
                    displayName: calendar.title,
                    color: Self.hexColor(from: calendar.cgColor),
                    provider: .local,
                    accountName: Self.accountName(for: calendar)
                )
            }
            .sorted(by: Self.accountThenName)
    }

    func scheduleEvents(start: Date, end: Date) -> [ScheduleEvent] {
        occurrences(start: start, end: end).map { occurrence in
            ScheduleEvent(
                eventId: occurrence.eventId,
                title: occurrence.title,
                startsAt: occurrence.startsAt,
                endsAt: occurrence.endsAt,
                allDay: occurrence.allDay,
                color: occurrence.color,
                calendarName: occurrence.calendarName
            )
        }
    }

    private func accessibleCalendars() -> [EKCalendar] {
        guard hasFullAccess else { return [] }
        return eventStore.calendars(for: .event)
    }

    private func selectedCalendars() -> [EKCalendar]? {
        let calendars = accessibleCalendars()
        guard hasSavedCalendarSelection else { return nil }
        let effectiveIds = effectiveSelectedCalendarIds()
        return calendars.filter { effectiveIds.contains($0.calendarIdentifier) }
    }

    private static func currentAccessStatus() -> NativeCalendarAccessStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .authorized
        case .denied, .writeOnly:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    private static func occurrence(from event: EKEvent) -> CalendarOccurrence {
        CalendarOccurrence(
            eventId: event.eventIdentifier ?? UUID().uuidString,
            calendarId: event.calendar.calendarIdentifier,
            title: event.title?.isEmpty == false ? event.title : "Untitled event",
            description: event.notes,
            location: event.location,
            startsAt: event.startDate,
            endsAt: event.endDate,
            allDay: event.isAllDay,
            color: hexColor(from: event.calendar.cgColor),
            calendarName: event.calendar.title,
            provider: .local,
            isBirthday: false,
            profileId: nil
        )
    }

    private static func accountThenName(_ lhs: CalendarPickerOption, _ rhs: CalendarPickerOption) -> Bool {
        let accountOrder = lhs.accountName.localizedCaseInsensitiveCompare(rhs.accountName)
        if accountOrder != .orderedSame {
            return accountOrder == .orderedAscending
        }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private static func accountName(for calendar: EKCalendar) -> String {
        let title = calendar.source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        switch calendar.source.sourceType {
        case .local:
            return "On My \(UIDevice.current.model)"
        case .exchange:
            return "Exchange"
        case .calDAV:
            return "CalDAV"
        case .mobileMe:
            return "iCloud"
        case .subscribed:
            return "Subscribed"
        case .birthdays:
            return "Birthdays"
        @unknown default:
            return "Other"
        }
    }

    private static func hexColor(from cgColor: CGColor?) -> String {
        guard let cgColor else { return "#4f7c6d" }
        let color = UIColor(cgColor: cgColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#4f7c6d"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(max(0, min(red, 1)) * 255),
            Int(max(0, min(green, 1)) * 255),
            Int(max(0, min(blue, 1)) * 255)
        )
    }
}
