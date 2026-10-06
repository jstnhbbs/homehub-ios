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

    var canManageReminderList: Bool {
        appState?.canManageHousehold ?? false
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
        guard let appState, appState.canManageHousehold else {
            refreshFromNativeServices()
            return
        }
        appState.nativeReminders.selectedListId = defaultReminderListId
        refreshFromNativeServices()
        Task { await appState.refreshNativeGroceryItems() }
    }

    /// Turns one calendar on or off. The choice is saved on the spot: there is no Save button to
    /// forget to press. The screen's own state updates at once, the choice is written to the device's
    /// preferences before this returns, and Today's schedule is refreshed shortly after (a short wait so
    /// flipping several toggles in a row refreshes once, not once each).
    func setCalendar(_ id: String, enabled: Bool) {
        guard let appState else { return }
        var ids = selectedCalendarIds
        if enabled { ids.insert(id) } else { ids.remove(id) }
        selectedCalendarIds = ids
        appState.nativeCalendar.saveSelectedCalendarIds(ids)
        refreshScheduleSoon(appState)
    }

    func selectAllCalendars() {
        guard let appState else { return }
        appState.nativeCalendar.selectAllCalendars()
        selectedCalendarIds = appState.nativeCalendar.effectiveSelectedCalendarIds()
        refreshScheduleSoon(appState)
    }

    private var scheduleRefreshTask: Task<Void, Never>?

    /// Holds on to `appState` itself (not this screen) so the refresh still happens if the person
    /// leaves the screen straight after a change.
    private func refreshScheduleSoon(_ appState: AppState) {
        scheduleRefreshTask?.cancel()
        scheduleRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await appState.refreshNativeTodaySchedule()
        }
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
