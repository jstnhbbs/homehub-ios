import EventKit
import Foundation
import UIKit

@MainActor
final class NativeRemindersService: ObservableObject {
    @Published private(set) var accessStatus: NativeRemindersAccessStatus
    @Published var selectedListId: String? {
        didSet {
            UserDefaults.standard.set(selectedListId, forKey: Self.selectedListKey)
        }
    }

    private static let selectedListKey = "homehub.reminders.selectedListId"
    private let eventStore = EKEventStore()

    init() {
        self.accessStatus = Self.currentAccessStatus()
        self.selectedListId = UserDefaults.standard.string(forKey: Self.selectedListKey)
    }

    var hasFullAccess: Bool {
        accessStatus == .authorized
    }

    var selectedList: EKCalendar? {
        guard let selectedListId, selectedListId != NativeCalendarPreferenceKeys.automaticId else {
            return eventStore.defaultCalendarForNewReminders()
        }
        return eventStore.calendar(withIdentifier: selectedListId) ?? eventStore.defaultCalendarForNewReminders()
    }

    var usesAutomaticList: Bool {
        selectedListId == nil || selectedListId == NativeCalendarPreferenceKeys.automaticId
    }

    func refreshAccessStatus() {
        accessStatus = Self.currentAccessStatus()
    }

    func resetCachedData() {
        eventStore.reset()
        refreshAccessStatus()
    }

    func requestFullAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            accessStatus = granted ? .authorized : Self.currentAccessStatus()
            if granted {
                eventStore.reset()
                if selectedListId == nil {
                    selectedListId = NativeCalendarPreferenceKeys.automaticId
                }
            }
        } catch {
            accessStatus = Self.currentAccessStatus()
        }
    }

    func reminderLists() -> [ReminderListOption] {
        guard hasFullAccess else { return [] }
        return eventStore.calendars(for: .reminder)
            .map { calendar in
                ReminderListOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    color: Self.hexColor(from: calendar.cgColor)
                )
            }
            .sorted { $0.title < $1.title }
    }

    func loadItems() async throws -> [GroceryItem] {
        guard hasFullAccess else { return [] }
        let calendars = selectedList.map { [$0] }
        let predicate = eventStore.predicateForReminders(in: calendars)
        let reminders = try await reminders(matching: predicate)
        return reminders
            .map(Self.groceryItem(from:))
            .sorted { lhs, rhs in
                if lhs.checked != rhs.checked { return !lhs.checked }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func addItem(title: String) throws -> GroceryItem {
        guard let calendar = selectedList else {
            throw NativeRemindersError.listUnavailable
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar
        try eventStore.save(reminder, commit: true)
        return Self.groceryItem(from: reminder)
    }

    func addItems(_ titles: [String]) throws -> Int {
        guard let calendar = selectedList else {
            throw NativeRemindersError.listUnavailable
        }
        var count = 0
        for title in titles {
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = cleaned
            reminder.calendar = calendar
            try eventStore.save(reminder, commit: false)
            count += 1
        }
        if count > 0 {
            try eventStore.commit()
        }
        return count
    }

    func setCompleted(itemId: String, completed: Bool) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: itemId) as? EKReminder else {
            throw NativeRemindersError.reminderNotFound
        }
        reminder.isCompleted = completed
        if completed {
            reminder.completionDate = .now
        } else {
            reminder.completionDate = nil
        }
        try eventStore.save(reminder, commit: true)
    }

    func deleteItem(itemId: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: itemId) as? EKReminder else {
            throw NativeRemindersError.reminderNotFound
        }
        try eventStore.remove(reminder, commit: true)
    }

    private func reminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private static func currentAccessStatus() -> NativeRemindersAccessStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private static func groceryItem(from reminder: EKReminder) -> GroceryItem {
        GroceryItem(
            id: reminder.calendarItemIdentifier,
            householdId: nil,
            title: reminder.title ?? "Untitled item",
            quantity: nil,
            category: reminder.calendar.title,
            checked: reminder.isCompleted,
            checkedAt: reminder.completionDate,
            sortOrder: 0,
            createdAt: nil,
            updatedAt: nil
        )
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

enum NativeRemindersError: LocalizedError {
    case reminderNotFound
    case listUnavailable

    var errorDescription: String? {
        switch self {
        case .reminderNotFound:
            "Reminder not found."
        case .listUnavailable:
            "No Reminders list is available."
        }
    }
}
