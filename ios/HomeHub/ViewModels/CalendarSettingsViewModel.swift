import Foundation
import UIKit

@MainActor
final class CalendarSettingsViewModel: ObservableObject {
    @Published var nativeAccessStatus: NativeCalendarAccessStatus = .notDetermined
    @Published var remindersAccessStatus: NativeRemindersAccessStatus = .notDetermined
    @Published var calendars: [CalendarPickerOption] = []
    @Published var writableCalendars: [CalendarPickerOption] = []
    @Published var reminderLists: [ReminderListOption] = []
    @Published var selectedCalendarIds: Set<String> = []
    @Published var defaultCalendarId = NativeCalendarPreferenceKeys.automaticId
    @Published var defaultReminderListId = NativeCalendarPreferenceKeys.automaticId
    @Published var weekStartsOn = WeekStart.defaultWeekStartsOn
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
        if let household = appState.household {
            weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
        }
        refreshFromNativeServices()
    }

    var hasCalendarAccess: Bool {
        nativeAccessStatus == .authorized
    }

    var needsCalendarPermission: Bool {
        nativeAccessStatus == .notDetermined
    }

    var calendarAccessDenied: Bool {
        nativeAccessStatus == .denied || nativeAccessStatus == .restricted
    }

    var hasRemindersAccess: Bool {
        remindersAccessStatus == .authorized
    }

    var needsRemindersPermission: Bool {
        remindersAccessStatus == .notDetermined
    }

    var remindersAccessDenied: Bool {
        remindersAccessStatus == .denied || remindersAccessStatus == .restricted
    }

    func load() async {
        guard appState != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        refreshFromNativeServices()
    }

    func requestNativeCalendarAccess() async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        await appState.nativeCalendar.requestFullAccess()
        refreshFromNativeServices()
        if hasCalendarAccess {
            await appState.refreshNativeTodaySchedule()
            successMessage = "Calendar access enabled."
        } else if calendarAccessDenied {
            errorMessage = "Calendar access is off. You can enable it in iOS Settings."
        } else {
            errorMessage = "Calendar access was not enabled."
        }
    }

    func requestNativeRemindersAccess() async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        await appState.nativeReminders.requestFullAccess()
        refreshFromNativeServices()
        if hasRemindersAccess {
            await appState.refreshNativeGroceryItems()
            successMessage = "Reminders access enabled."
        } else if remindersAccessDenied {
            errorMessage = "Reminders access is off. You can enable it in iOS Settings."
        } else {
            errorMessage = "Reminders access was not enabled."
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func saveDefaultCalendar() {
        guard let appState else { return }
        appState.nativeCalendar.defaultCalendarId = defaultCalendarId
        refreshFromNativeServices()
    }

    func saveDefaultReminderList() {
        guard let appState else { return }
        appState.nativeReminders.selectedListId = defaultReminderListId
        refreshFromNativeServices()
        Task { await appState.refreshNativeGroceryItems() }
    }

    func saveCalendarSelection() async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        appState.nativeCalendar.saveSelectedCalendarIds(selectedCalendarIds)
        refreshFromNativeServices()
        await appState.refreshNativeTodaySchedule()
        await appState.refreshDashboard()
        successMessage = "Calendar selection saved."
        return true
    }

    func selectAllCalendars() async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        appState.nativeCalendar.selectAllCalendars()
        refreshFromNativeServices()
        await appState.refreshNativeTodaySchedule()
        await appState.refreshDashboard()
        successMessage = "All calendars selected."
    }

    func saveWeekStart() async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let household = try await appState.api.updateCalendarSettings(
                UpdateCalendarSettingsRequest(
                    weekStartsOn: weekStartsOn
                )
            )
            appState.household = household
            await appState.refreshDashboard()
            weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            successMessage = "Calendar settings saved."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshFromNativeServices() {
        guard let appState else { return }
        appState.nativeCalendar.refreshAccessStatus()
        appState.nativeReminders.refreshAccessStatus()
        nativeAccessStatus = appState.nativeCalendar.accessStatus
        remindersAccessStatus = appState.nativeReminders.accessStatus
        calendars = appState.nativeCalendar.pickerOptions()
        writableCalendars = appState.nativeCalendar.writablePickerOptions()
        reminderLists = appState.nativeReminders.reminderLists()
        selectedCalendarIds = appState.nativeCalendar.effectiveSelectedCalendarIds()
        defaultCalendarId = appState.nativeCalendar.usesAutomaticDefaultCalendar
            ? NativeCalendarPreferenceKeys.automaticId
            : appState.nativeCalendar.defaultCalendarId
        defaultReminderListId = appState.nativeReminders.usesAutomaticList
            ? NativeCalendarPreferenceKeys.automaticId
            : (appState.nativeReminders.selectedListId ?? NativeCalendarPreferenceKeys.automaticId)
    }
}
