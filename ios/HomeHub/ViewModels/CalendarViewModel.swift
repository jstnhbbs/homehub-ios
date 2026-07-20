import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var viewMode: CalendarViewMode = .month
    @Published var anchorDate = Date.now
    @Published var selectedDate = ""
    @Published var searchQuery = ""
    @Published var occurrences: [CalendarOccurrence] = []
    @Published var calendars: [CalendarPickerOption] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var editingEvent: CalendarOccurrence?
    @Published var showAddEvent = false

    private var appState: AppState?
    private var autoSyncTask: Task<Void, Never>?
    private var lastAutoSyncAt: Date?

    func bind(to appState: AppState) {
        self.appState = appState
        if selectedDate.isEmpty, let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
            selectedDate = DateHelpers.localDateIn(timezone: timezone)
        }
    }

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var weekStartsOn: Int {
        appState?.household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn
    }

    var today: String {
        DateHelpers.localDateIn(timezone: timezone)
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var isConnected: Bool {
        appState?.dashboard?.calendarStatus.connected ?? false
    }

    var headerTitle: String {
        switch viewMode {
        case .month:
            return CalendarHelpers.monthTitle(anchorDate, timezone: timezone)
        case .week:
            let days = CalendarHelpers.weekDates(anchor: anchorDate, timezone: timezone, weekStartsOn: weekStartsOn)
            if let first = days.first, let last = days.last {
                return CalendarHelpers.weekTitle(start: first, end: last, timezone: timezone)
            }
            return ""
        case .day:
            return CalendarHelpers.agendaTitle(selectedDate, timezone: timezone)
        }
    }

    var gridDates: [Date] {
        switch viewMode {
        case .month:
            CalendarHelpers.monthGridDates(anchor: anchorDate, timezone: timezone, weekStartsOn: weekStartsOn)
        case .week:
            CalendarHelpers.weekDates(anchor: anchorDate, timezone: timezone, weekStartsOn: weekStartsOn)
        case .day:
            [anchorDate]
        }
    }

    var selectedDayEvents: [CalendarOccurrence] {
        CalendarHelpers.eventsForDate(filteredOccurrences, on: selectedDate, timezone: timezone)
    }

    var filteredOccurrences: [CalendarOccurrence] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return occurrences }
        return occurrences.filter {
            "\($0.title) \($0.location ?? "") \($0.calendarName)".lowercased().contains(query)
        }
    }

    func events(on localDate: String) -> [CalendarOccurrence] {
        CalendarHelpers.eventsForDate(filteredOccurrences, on: localDate, timezone: timezone)
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let (start, end) = CalendarHelpers.rangeStartEnd(
            viewMode: viewMode,
            anchor: anchorDate,
            timezone: timezone,
            weekStartsOn: weekStartsOn
        )

        do {
            async let eventsTask = appState.api.fetchCalendarOccurrences(start: start, end: end, query: searchQuery)
            async let calendarsTask = appState.api.fetchCalendarPickerOptions()
            occurrences = try await eventsTask
            calendars = try await calendarsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncCalendars() async {
        guard let appState else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await appState.api.syncCalendar(force: true)
            lastAutoSyncAt = .now
            await load()
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAutoSync(appState: AppState) {
        stopAutoSync()
        self.appState = appState
        guard isConnected else { return }
        let minutes = CalendarSyncInterval.parse(appState.household?.calendarSyncIntervalMinutes)
        guard minutes > 0 else { return }

        let interval = CalendarSyncInterval.intervalSeconds(minutes)
        autoSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            while !Task.isCancelled {
                await self?.performAutoSync()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopAutoSync() {
        autoSyncTask?.cancel()
        autoSyncTask = nil
    }

    private func performAutoSync() async {
        guard let appState, isConnected, !isSyncing else { return }
        let minutes = CalendarSyncInterval.parse(appState.household?.calendarSyncIntervalMinutes)
        let cooldown = CalendarSyncInterval.cooldownSeconds(minutes)
        if let lastAutoSyncAt, Date.now.timeIntervalSince(lastAutoSyncAt) < cooldown {
            return
        }
        if let lastSynced = appState.dashboard?.calendarStatus.lastSyncedAt,
           Date.now.timeIntervalSince(lastSynced) < cooldown {
            return
        }

        isSyncing = true
        defer { isSyncing = false }
        do {
            try await appState.api.syncCalendar(force: false)
            lastAutoSyncAt = .now
            await load()
            await appState.refreshDashboard()
        } catch {
            // Keep auto-sync quiet; manual sync still shows errors.
        }
    }

    func goToToday() {
        anchorDate = Date.now
        selectedDate = today
        if viewMode == .day {
            anchorDate = CalendarHelpers.parseLocalDate(selectedDate, timezone: timezone) ?? .now
        }
    }

    func goPrevious() {
        shiftAnchor(by: -1)
    }

    func goNext() {
        shiftAnchor(by: 1)
    }

    func selectDate(_ localDate: String) {
        selectedDate = localDate
        if let date = CalendarHelpers.parseLocalDate(localDate, timezone: timezone) {
            anchorDate = date
        }
    }

    func setViewMode(_ mode: CalendarViewMode) {
        viewMode = mode
        if mode == .day, let date = CalendarHelpers.parseLocalDate(selectedDate, timezone: timezone) {
            anchorDate = date
        }
    }

    func editableCalendars(for event: CalendarOccurrence) -> [CalendarPickerOption] {
        guard let provider = event.provider else { return [] }
        return calendars.filter { $0.provider == provider }
    }

    func createEvent(_ input: CalendarEventFormInput) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.createCalendarEvent(input)
            showAddEvent = false
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateEvent(id: String, input: CalendarEventFormInput) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.updateCalendarEvent(id: id, input: input)
            editingEvent = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteEvent(id: String) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.deleteCalendarEvent(id: id)
            editingEvent = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func shiftAnchor(by direction: Int) {
        let cal = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: weekStartsOn)
        switch viewMode {
        case .month:
            anchorDate = cal.date(byAdding: .month, value: direction, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = cal.date(byAdding: .day, value: 7 * direction, to: anchorDate) ?? anchorDate
            selectedDate = CalendarHelpers.localDate(for: anchorDate, timezone: timezone)
        case .day:
            anchorDate = cal.date(byAdding: .day, value: direction, to: anchorDate) ?? anchorDate
            selectedDate = CalendarHelpers.localDate(for: anchorDate, timezone: timezone)
        }
    }
}
