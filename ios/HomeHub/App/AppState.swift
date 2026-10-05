import Foundation
import SwiftUI

enum AppConfig {
    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "HOMEHUB_API_URL") as? String,
           let url = URL(string: value) {
            return url
        }
        return URL(string: "http://localhost:3000")!
    }
}

@MainActor
final class AppState: ObservableObject {
    let auth: AuthService
    let api: HomeHubAPI
    let nativeCalendar: NativeCalendarService
    let nativeReminders: NativeRemindersService
    let nativeNotifications: NativeNotificationService
    let nativeWeather: NativeWeatherService
    let localStore: HomeHubLocalStore

    @Published var household: Household?
    @Published var dashboard: DashboardData?
    /// Whether the household has any anniversary. Views that show the module's name read
    /// `CelebrationNaming.current`, and observing this makes them redraw when it changes.
    @Published private(set) var hasAnniversaries = CelebrationNaming.hasAnniversaries()
    @Published var nativeTodayScheduleEvents: [ScheduleEvent] = []
    @Published var nativeGroceryItems: [GroceryItem] = []
    @Published var hubModules: HubModules = .defaults
    @Published var selectedDestination: HubDestination = .dashboard
    @Published var pendingFoodSection: FoodHubSection?
    @Published var pendingProfileEditId: String?
    @Published var isBootstrapping = true
    @Published var errorMessage: String?
    @Published var accentPalette: AccentPalette {
        didSet {
            HubTheme.currentAccent = accentPalette
            UserDefaults.standard.set(accentPalette.rawValue, forKey: Self.accentStorageKey)
        }
    }
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceStorageKey)
        }
    }

    private static let accentStorageKey = "homehub.accentPalette"
    private static let appearanceStorageKey = "homehub.appearanceMode"

    private var eventKitObserver: NSObjectProtocol?
    private var eventKitRefreshTask: Task<Void, Never>?
    private var hubModulesSaveVersion = 0
    private var pendingHubModulesSave: HubModules?
    private var locallySavedHubModules: HubModules?

    init(baseURL: URL = AppConfig.baseURL) {
        self.auth = AuthService(baseURL: baseURL)
        self.api = HomeHubAPI(baseURL: baseURL)
        self.nativeCalendar = NativeCalendarService()
        self.nativeReminders = NativeRemindersService()
        self.nativeNotifications = NativeNotificationService()
        self.nativeWeather = NativeWeatherService()
        self.localStore = HomeHubLocalStore()
        let stored = UserDefaults.standard.string(forKey: Self.accentStorageKey) ?? ""
        let palette = AccentPalette(rawValue: stored) ?? .sage
        self.accentPalette = palette
        HubTheme.currentAccent = palette
        let storedMode = UserDefaults.standard.string(forKey: Self.appearanceStorageKey) ?? ""
        self.appearanceMode = AppearanceMode(rawValue: storedMode) ?? .system
        observeEventKitChanges()
    }

    deinit {
        eventKitRefreshTask?.cancel()
        if let eventKitObserver {
            NotificationCenter.default.removeObserver(eventKitObserver)
        }
    }

    var needsOnboarding: Bool {
        auth.isSignedIn && household == nil
    }

    var canManageHousehold: Bool {
        guard let role = household?.role else { return false }
        return HouseholdRoles.canManageHousehold(role: role)
    }

    var isOwner: Bool {
        guard let role = household?.role else { return false }
        return HouseholdRoles.isOwner(role: role)
    }

    var currentUser: User? {
        auth.currentUser
    }

    var isGuest: Bool {
        guard let role = household?.role else { return false }
        return HouseholdRoles.isGuest(role: role)
    }

    func myProfile(from profiles: [Profile]) -> Profile? {
        guard let userId = auth.currentUser?.id else { return nil }
        return profiles.first { $0.userId == userId }
    }

    func canEditProfile(_ profileId: String, profiles: [Profile]) -> Bool {
        if canManageHousehold { return true }
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return false }
        return profile.userId == currentUser?.id
    }

    func openProfileEdit(profileId: String) {
        pendingProfileEditId = profileId
        if canManageHousehold {
            selectedDestination = .settings
        } else {
            selectedDestination = .profile
        }
    }

    func bootstrap() async {
        isBootstrapping = true
        await auth.restoreSession()
        guard auth.isSignedIn else {
            household = nil
            dashboard = nil
            hubModules = .defaults
            pendingHubModulesSave = nil
            selectedDestination = .dashboard
            pendingFoodSection = nil
            pendingProfileEditId = nil
            localStore.clear()
            HomeHubWidgetStore.clear()
            isBootstrapping = false
            return
        }

        hydrateFromLocalStore()
        let hasCachedLaunchData = household != nil || dashboard != nil
        if hasCachedLaunchData {
            isBootstrapping = false
        }

        await refreshHousehold()

        if !hasCachedLaunchData {
            isBootstrapping = false
        }
    }

    func refreshHousehold() async {
        do {
            household = try await api.fetchHousehold()
            localStore.saveHousehold(household)
            if household != nil {
                await refreshDashboard()
            } else {
                dashboard = nil
            }
        } catch {
            hydrateFromLocalStore()
            errorMessage = error.localizedDescription
        }
    }

    func refreshDashboard() async {
        errorMessage = nil
        do {
            dashboard = try await api.fetchDashboard()
            household = dashboard?.household
            if let dashboard {
                setHasAnniversaries(dashboard.hasAnniversaries)
            }
            localStore.saveDashboard(dashboard)
            if let modules = dashboard?.hubModules {
                applyHubModules(preferredHubModules(for: modules))
            }
            await refreshNativeTodaySchedule()
            await refreshNativeGroceryItems()
            await refreshNativeWeather()
            if let dashboard {
                await nativeNotifications.scheduleDashboardReminders(
                    from: dashboard,
                    birthdaysModuleEnabled: hubModules.isEnabled(.birthdays)
                )
            }
            publishWidgetSummary()
            if let dashboard {
                await SleepLiveActivityManager.sync(
                    logs: dashboard.naps,
                    children: NapHelpers.childProfiles(from: dashboard.profiles)
                )
            }
        } catch {
            hydrateFromLocalStore()
            errorMessage = error.localizedDescription
        }
    }

    /// Remembers whether the household has an anniversary, which decides whether the module reads
    /// "Birthdays" or "Celebrations". Only fresh server data should set this: a cached dashboard from
    /// an older version has no such field and would wrongly say false.
    func setHasAnniversaries(_ value: Bool) {
        guard value != hasAnniversaries else { return }
        CelebrationNaming.setHasAnniversaries(value)
        hasAnniversaries = value
    }

    func rescheduleNativeNotifications() async {
        guard let dashboard else { return }
        await nativeNotifications.scheduleDashboardReminders(
            from: dashboard,
            birthdaysModuleEnabled: hubModules.isEnabled(.birthdays)
        )
    }

    func refreshNativeTodaySchedule() async {
        nativeCalendar.refreshAccessStatus()
        guard nativeCalendar.hasFullAccess else {
            nativeTodayScheduleEvents = []
            publishWidgetSummary()
            return
        }

        let timezone = household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
        let localDate = DateHelpers.localDateIn(timezone: timezone)
        guard let day = CalendarHelpers.parseLocalDate(localDate, timezone: timezone) else {
            nativeTodayScheduleEvents = []
            publishWidgetSummary()
            return
        }

        var calendar = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn)
        calendar.timeZone = timezone
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
        nativeTodayScheduleEvents = nativeCalendar.scheduleEvents(start: start, end: end)
        publishWidgetSummary()
    }

    func refreshNativeGroceryItems() async {
        nativeReminders.refreshAccessStatus()
        guard nativeReminders.hasFullAccess, nativeReminders.selectedListId != nil else {
            nativeGroceryItems = []
            return
        }

        do {
            nativeGroceryItems = try await nativeReminders.loadItems()
        } catch {
            errorMessage = error.localizedDescription
            nativeGroceryItems = []
        }
    }

    // MARK: - Completion actions
    //
    // One home for "what endpoint, what payload, and what to refresh afterwards" so the
    // dashboard cards, the compact tiles, and the view models can't drift apart. These
    // throw rather than swallowing, because each caller wants its own failure handling:
    // view models surface `errorMessage`, tiles animate a checkmark back off.

    /// `refreshingDashboard: false` lets a caller run its own completion animation
    /// first and refresh afterwards, instead of re-rendering mid-animation.
    /// `completed` is the state to leave the step in. Pass it whenever the caller knows it, so a
    /// retried or doubled request is harmless; nil asks the server to flip the step.
    func toggleRoutineStep(stepId: String, localDate: String, completed: Bool? = nil, refreshingDashboard: Bool = true) async throws {
        try await api.toggleRoutineStep(
            ToggleRoutineStepRequest(stepId: stepId, localDate: localDate, completed: completed)
        )
        if refreshingDashboard {
            await refreshDashboard()
        }
    }

    func toggleChore(choreId: String, periodKey: String, completed: Bool? = nil) async throws {
        try await api.toggleChore(
            ToggleChoreRequest(choreId: choreId, periodKey: periodKey, completed: completed)
        )
        await refreshDashboard()
    }

    func toggleSnack(localDate: String, label: String, profileId: String? = nil, completed: Bool? = nil) async throws {
        try await api.toggleSnack(
            ToggleSnackRequest(localDate: localDate, snackLabel: label, profileId: profileId, completed: completed)
        )
        await refreshDashboard()
    }

    /// True when grocery writes should go to the device Reminders list instead of the API.
    var groceriesUseNativeReminders: Bool {
        nativeReminders.hasFullAccess && nativeReminders.selectedListId != nil
    }

    /// Routes to Reminders or the API depending on the household's grocery source. This
    /// branch was previously copy-pasted at three call sites.
    func setGroceryItemChecked(id: String, checked: Bool) async throws {
        if groceriesUseNativeReminders {
            try nativeReminders.setCompleted(itemId: id, completed: checked)
            await refreshNativeGroceryItems()
            await refreshDashboard()
        } else {
            _ = try await api.toggleGroceryItem(id: id, checked: checked)
            await refreshDashboard()
        }
    }

    func refreshNativeDataFromEventKitChange() async {
        nativeCalendar.resetCachedData()
        nativeReminders.resetCachedData()
        await refreshNativeTodaySchedule()
        await refreshNativeGroceryItems()
    }

    func requestNativeWeatherAccessAndRefresh() async {
        await nativeWeather.requestAccessAndRefresh()
    }

    func refreshNativeWeather() async {
        await nativeWeather.refreshWeather()
        publishWidgetSummary()
    }

    func applyHubModules(_ modules: HubModules) {
        hubModules = modules
        if dashboard?.hubModules != modules {
            dashboard?.hubModules = modules
            localStore.saveDashboard(dashboard)
        }
        normalizeNavigation()
    }

    func saveHubModules(_ modules: HubModules) async {
        hubModulesSaveVersion += 1
        let saveVersion = hubModulesSaveVersion
        pendingHubModulesSave = modules
        locallySavedHubModules = modules
        let birthdaysWereEnabled = hubModules.isEnabled(.birthdays)
        applyHubModules(modules)
        // The Birthdays module also gates birthday reminders, so re-plan them when it flips.
        if birthdaysWereEnabled != modules.isEnabled(.birthdays) {
            await rescheduleNativeNotifications()
        }
        do {
            let savedModules = try await api.saveHubModules(modules)
            if saveVersion == hubModulesSaveVersion {
                pendingHubModulesSave = nil
                applyHubModules(savedModules == modules ? savedModules : modules)
            }
        } catch {
            if saveVersion == hubModulesSaveVersion {
                pendingHubModulesSave = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func normalizeNavigation() {
        if !selectedDestination.isVisible(in: hubModules) {
            selectedDestination = .dashboard
        }
        if let pending = pendingFoodSection, !pending.isVisible(in: hubModules) {
            pendingFoodSection = nil
        }
    }

    func refreshSession() async {
        await auth.restoreSession()
    }

    func signOut() async {
        await auth.signOut()
        household = nil
        dashboard = nil
        hubModules = .defaults
        pendingHubModulesSave = nil
        locallySavedHubModules = nil
        setHasAnniversaries(false)
        localStore.clear()
        HomeHubWidgetStore.clear()
        await SleepLiveActivityManager.endAll()
        pendingProfileEditId = nil
        selectedDestination = .dashboard
    }

    private func hydrateFromLocalStore() {
        if dashboard == nil, let cachedDashboard = localStore.loadDashboard() {
            dashboard = cachedDashboard
            household = cachedDashboard.household
            if let modules = cachedDashboard.hubModules {
                applyHubModules(modules)
            }
            publishWidgetSummary()
        } else if household == nil, let cachedHousehold = localStore.loadHousehold() {
            household = cachedHousehold
        }
    }

    private func preferredHubModules(for incoming: HubModules) -> HubModules {
        if let pendingHubModulesSave {
            return pendingHubModulesSave
        }

        guard let locallySavedHubModules else {
            return incoming
        }

        if incoming == locallySavedHubModules {
            self.locallySavedHubModules = nil
            return incoming
        }

        return locallySavedHubModules
    }

    private func publishWidgetSummary() {
        guard let dashboard else { return }

        let timezone = TimeZone(identifier: dashboard.household.timezone) ?? .current
        let scheduleEvents = nativeCalendar.hasFullAccess ? nativeTodayScheduleEvents : []
        let nextEvent = DashboardHelpers.upcomingScheduleEvents(scheduleEvents, now: .now).first
        let dinnerTitle = dashboard.meals
            .first { $0.localDate == dashboard.localDate && $0.slot == .dinner }?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let summary = HomeHubWidgetSummary(
            householdName: dashboard.household.name,
            localDate: DateHelpers.headerDateLabel(timezone: timezone),
            pendingRoutineCount: dashboard.routineSteps.filter { !$0.completed }.count,
            pendingChoreCount: dashboard.chores.filter { !$0.completed && $0.dueToday != false }.count,
            dinnerTitle: dinnerTitle?.isEmpty == false ? dinnerTitle : nil,
            nextEventTitle: nextEvent?.title,
            nextEventTime: nextEvent.map { event in
                event.allDay ? "All day" : DateHelpers.timeString(event.startsAt, timezone: timezone)
            },
            weatherTemperature: nativeWeather.snapshot?.temperature,
            weatherCondition: nativeWeather.snapshot?.condition,
            updatedAt: .now
        )

        HomeHubWidgetStore.save(summary)
    }

    private func observeEventKitChanges() {
        eventKitObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleEventKitRefresh()
            }
        }
    }

    private func scheduleEventKitRefresh() {
        eventKitRefreshTask?.cancel()
        eventKitRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshNativeDataFromEventKitChange()
        }
    }
}
