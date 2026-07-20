import Foundation

@MainActor
final class CalendarSettingsViewModel: ObservableObject {
    @Published var connections: [CalendarConnection] = []
    @Published var calendars: [HouseholdCalendarOption] = []
    @Published var selectedCalendarIds: Set<String> = []
    @Published var weekStartsOn = WeekStart.defaultWeekStartsOn
    @Published var syncIntervalMinutes = CalendarSyncInterval.defaultMinutes
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var appleEmail = ""
    @Published var applePassword = ""

    private var appState: AppState?
    private var lastAutoSyncAt: Date?

    func bind(to appState: AppState) {
        self.appState = appState
        if let household = appState.household {
            weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            syncIntervalMinutes = CalendarSyncInterval.parse(household.calendarSyncIntervalMinutes)
        }
    }

    var icloudConnection: CalendarConnection? {
        connections.first { $0.provider == .icloud }
    }

    var googleConnection: CalendarConnection? {
        connections.first { $0.provider == .google }
    }

    func calendars(for provider: CalendarProvider) -> [HouseholdCalendarOption] {
        calendars.filter { $0.provider == provider }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let connectionsTask = appState.api.fetchCalendarConnections()
            async let calendarsTask = appState.api.fetchHouseholdCalendars()
            connections = try await connectionsTask
            calendars = try await calendarsTask
            selectedCalendarIds = Set(calendars.filter(\.enabled).map(\.id))
            if let household = appState.household {
                weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
                syncIntervalMinutes = CalendarSyncInterval.parse(household.calendarSyncIntervalMinutes)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectApple() async -> Bool {
        guard let appState else { return false }
        let username = appleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = applePassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, password.count >= 16 else {
            errorMessage = "Enter your Apple Account email and app-specific password."
            return false
        }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            try await appState.api.connectICloudCalendar(
                ConnectICloudRequest(username: username, password: password)
            )
            applePassword = ""
            try await appState.api.syncCalendar(force: true)
            await load()
            await appState.refreshDashboard()
            successMessage = "Apple Calendar connected."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func connectGoogle() async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let url = try await appState.api.fetchGoogleCalendarConnectURL()
            let callbackURL = try await GoogleCalendarAuth.connect(authURL: url)
            let result = GoogleCalendarAuth.resultMessage(from: callbackURL)
            if let error = result.error {
                errorMessage = error
                return false
            }
            try await appState.api.syncCalendar(force: true)
            await load()
            await appState.refreshDashboard()
            successMessage = result.success ?? "Google Calendar connected."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func disconnect(provider: CalendarProvider) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            try await appState.api.disconnectCalendar(provider: provider)
            await load()
            await appState.refreshDashboard()
            successMessage = "\(provider == .google ? "Google" : "Apple") Calendar disconnected."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveCalendarSelection() async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            calendars = try await appState.api.updateCalendarSelection(
                calendarIds: Array(selectedCalendarIds)
            )
            selectedCalendarIds = Set(calendars.filter(\.enabled).map(\.id))
            await appState.refreshDashboard()
            successMessage = "Calendar selection saved."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveWeekStart() async -> Bool {
        await saveSettings(weekStartsOn: weekStartsOn, syncIntervalMinutes: nil)
    }

    func saveSyncInterval() async -> Bool {
        await saveSettings(weekStartsOn: nil, syncIntervalMinutes: syncIntervalMinutes)
    }

    func syncNow() async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await appState.api.syncCalendar(force: true)
            await load()
            await appState.refreshDashboard()
            successMessage = "Calendars synced."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func maybeAutoSync() async {
        guard let appState, connections.contains(where: { $0.status == .connected }) else { return }
        let minutes = CalendarSyncInterval.parse(appState.household?.calendarSyncIntervalMinutes)
        guard minutes > 0 else { return }

        let cooldown = CalendarSyncInterval.cooldownSeconds(minutes)
        if let lastAutoSyncAt, Date.now.timeIntervalSince(lastAutoSyncAt) < cooldown {
            return
        }
        if let lastSynced = appState.dashboard?.calendarStatus.lastSyncedAt,
           Date.now.timeIntervalSince(lastSynced) < cooldown {
            return
        }

        lastAutoSyncAt = .now
        do {
            try await appState.api.syncCalendar(force: false)
            await load()
            await appState.refreshDashboard()
        } catch {
            // Auto-sync failures stay quiet unless manual sync is used.
        }
    }

    private func saveSettings(weekStartsOn: Int?, syncIntervalMinutes: Int?) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let household = try await appState.api.updateCalendarSettings(
                UpdateCalendarSettingsRequest(
                    weekStartsOn: weekStartsOn,
                    calendarSyncIntervalMinutes: syncIntervalMinutes
                )
            )
            appState.household = household
            await appState.refreshDashboard()
            self.weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            self.syncIntervalMinutes = CalendarSyncInterval.parse(household.calendarSyncIntervalMinutes)
            successMessage = "Calendar settings saved."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
