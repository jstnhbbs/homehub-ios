import Combine
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
    /// Set when the whole screen has nothing to show (no dashboard yet); the Today screen draws it.
    @Published var errorMessage: String?
    /// A short message about something that failed while the person was using the app, shown as a
    /// banner over whatever screen they are on (see `RootView`). `errorMessage` is not enough for
    /// this: it only appears when there is no dashboard, so a failed note or check-off would
    /// otherwise say nothing at all. Use `report(_:)` from views.
    @Published private(set) var notice: String?
    private var noticeTask: Task<Void, Never>?
    /// Passes `AuthService` changes on, so screens that read `currentUser` (such as whether the email
    /// address is confirmed yet) redraw when it changes.
    private var authObserver: AnyCancellable?
    @Published var accentPalette: AccentPalette {
        didSet {
            HubTheme.currentAccent = accentPalette
            UserDefaults.standard.set(accentPalette.rawValue, forKey: Self.accentStorageKey)
        }
    }

    /// Light, dark or automatic, saved on this device.
    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Self.appearanceModeKey) }
    }
    /// Pure black pages in dark mode instead of charcoal, saved on this device.
    @Published var usesTrueBlack: Bool {
        didSet {
            HubTheme.usesTrueBlack = usesTrueBlack
            UserDefaults.standard.set(usesTrueBlack, forKey: Self.trueBlackKey)
        }
    }

    /// Shows the failure as a banner for a few seconds. A cancelled request says nothing.
    func report(_ error: Error) {
        guard let message = error.userFacingMessage else { return }
        showNotice(message)
    }

    func showNotice(_ message: String) {
        notice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    func dismissNotice() {
        noticeTask?.cancel()
        notice = nil
    }

    private static let accentStorageKey = "homehub.accentPalette"
    private static let appearanceModeKey = "homehub.appearanceMode"
    private static let trueBlackKey = "homehub.trueBlack"

    private var eventKitObserver: NSObjectProtocol?
    private var dataChangedObserver: NSObjectProtocol?
    private var openDestinationObserver: NSObjectProtocol?
    private var eventKitRefreshTask: Task<Void, Never>?
    private var lastDeviceRefreshAt: Date?
    private var hubModulesSaveVersion = 0
    private var pendingHubModulesSave: HubModules?
    private var locallySavedHubModules: HubModules?
    private var dashboardRequestVersion = 0
    private var householdRequestVersion = 0

    private func isCurrentSession(_ version: Int, userId: String?) -> Bool {
        !Task.isCancelled && auth.isSignedIn
            && auth.sessionVersion == version && currentUser?.id == userId
    }

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
        let defaults = UserDefaults.standard
        self.appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Self.appearanceModeKey) ?? "") ?? .system
        let trueBlack = defaults.bool(forKey: Self.trueBlackKey)
        self.usesTrueBlack = trueBlack
        HubTheme.usesTrueBlack = trueBlack
        observeEventKitChanges()
        // A button on a notification (Done on a chore, End Nap) changed something: show it.
        dataChangedObserver = NotificationCenter.default.addObserver(
            forName: .homeHubDataChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshDashboard() }
        }
        // A tap on a notification opens the page it is about (Routines, Chores, Sleep, Celebrations).
        openDestinationObserver = NotificationCenter.default.addObserver(
            forName: .homeHubOpenDestination, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openPendingNotificationDestination() }
        }
        authObserver = auth.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        eventKitRefreshTask?.cancel()
        if let eventKitObserver {
            NotificationCenter.default.removeObserver(eventKitObserver)
        }
        if let dataChangedObserver {
            NotificationCenter.default.removeObserver(dataChangedObserver)
        }
        if let openDestinationObserver {
            NotificationCenter.default.removeObserver(openDestinationObserver)
        }
    }

    /// Goes to the page a tapped notification asked for, if the person is signed in and has that
    /// page turned on. Also called after launch, for a tap that started the app.
    func openPendingNotificationDestination() {
        // Left in place until the person is signed in and their screens are loaded, so a tap that
        // launched the app is not lost while the saved session is still being checked.
        guard auth.isSignedIn, household != nil || dashboard != nil,
              let raw = NotificationResponder.takePendingDestination(),
              let destination = HubDestination(rawValue: raw),
              destination.isVisible(in: hubModules) else { return }
        selectedDestination = destination
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
        defer { isBootstrapping = false }

        // Open straight to the saved screens when there are any, then check the session behind them.
        // Waiting for the server first meant a slow or missing connection left a spinner (or, before,
        // the sign-in screen) where the app should have been.
        if let savedUser = localStore.loadUser() {
            auth.adoptSavedUser(savedUser)
            hydrateFromLocalStore()
            if household != nil || dashboard != nil {
                isBootstrapping = false
            }
        }

        let launchSession = auth.sessionVersion
        let check = await auth.restoreSession()
        guard launchSession == auth.sessionVersion else { return }
        if check == .signedIn {
            localStore.saveUser(auth.currentUser)
        }

        guard auth.isSignedIn else {
            auth.endSessionLocally()
            let endedSession = auth.sessionVersion
            let notificationCleanup = clearSignedInState()
            await notificationCleanup.value
            guard endedSession == auth.sessionVersion else { return }
            await SleepLiveActivityManager.endAll()
            isBootstrapping = false
            return
        }

        hydrateFromLocalStore()
        let hasCachedLaunchData = household != nil || dashboard != nil
        if hasCachedLaunchData {
            isBootstrapping = false
            openPendingNotificationDestination()
        }

        await refreshHousehold()
        openPendingNotificationDestination()

        if !hasCachedLaunchData {
            isBootstrapping = false
        }
    }

    func refreshHousehold() async {
        guard auth.isSignedIn else { return }
        let session = auth.sessionVersion
        let userId = currentUser?.id
        householdRequestVersion += 1
        let request = householdRequestVersion
        do {
            let fresh = try await api.fetchHousehold()
            guard isCurrentSession(session, userId: userId), request == householdRequestVersion else { return }
            household = fresh
            localStore.saveHousehold(household)
            localStore.saveUser(auth.currentUser)
            if household != nil {
                await refreshDashboard()
            } else {
                dashboardRequestVersion += 1
                dashboard = nil
            }
        } catch {
            guard isCurrentSession(session, userId: userId), request == householdRequestVersion else { return }
            if case APIError.unauthorized = error {
                await handleSessionExpired()
                return
            }
            hydrateFromLocalStore()
            errorMessage = error.localizedDescription
        }
    }

    /// The server no longer accepts this device's session (it expired, or was ended from somewhere
    /// else). Nothing more can be saved or loaded, so go back to sign-in and say why, rather than
    /// leave every screen failing.
    func handleSessionExpired() async {
        auth.endSessionLocally()
        let endedSession = auth.sessionVersion
        let notificationCleanup = clearSignedInState()
        await notificationCleanup.value
        guard endedSession == auth.sessionVersion else { return }
        await SleepLiveActivityManager.endAll()
        showNotice("You were signed out. Please sign in again.")
    }

    /// Calendar, Reminders and weather are read from the device, and the system tells us the moment a
    /// calendar or reminder changes (see `observeEventKitChanges`), so re-reading them on every
    /// refresh, which happens after each check-off and every minute, is wasted work. They are read at
    /// most this often unless the person asks (pull to refresh).
    private static let minimumDeviceRefreshInterval: TimeInterval = 5 * 60

    /// `forcingDeviceRefresh` re-reads the device's calendars, reminders and weather even if that was
    /// done recently.
    func refreshDashboard(forcingDeviceRefresh: Bool = false) async {
        guard auth.isSignedIn else { return }
        let session = auth.sessionVersion
        let userId = currentUser?.id
        dashboardRequestVersion += 1
        let request = dashboardRequestVersion
        errorMessage = nil
        do {
            let fresh = try await api.fetchDashboard()
            guard isCurrentSession(session, userId: userId), request == dashboardRequestVersion else { return }
            householdRequestVersion += 1
            dashboard = fresh
            household = dashboard?.household
            if let dashboard {
                setHasAnniversaries(dashboard.hasAnniversaries)
            }
            localStore.saveDashboard(dashboard)
            if let modules = dashboard?.hubModules {
                applyHubModules(preferredHubModules(for: modules))
            }
            if forcingDeviceRefresh || shouldRefreshDeviceData {
                lastDeviceRefreshAt = .now
                await refreshNativeTodaySchedule()
                await refreshNativeGroceryItems()
                await refreshNativeWeather()
            }
            guard isCurrentSession(session, userId: userId), request == dashboardRequestVersion else { return }
            if let dashboard {
                await nativeNotifications.scheduleDashboardReminders(
                    from: dashboard,
                    birthdaysModuleEnabled: hubModules.isEnabled(.birthdays)
                )
            }
            guard isCurrentSession(session, userId: userId), request == dashboardRequestVersion else { return }
            if let dashboard {
                await SleepLiveActivityManager.sync(
                    logs: dashboard.naps,
                    children: NapHelpers.childProfiles(from: dashboard.profiles)
                )
            }
        } catch {
            guard isCurrentSession(session, userId: userId), request == dashboardRequestVersion else { return }
            if case APIError.unauthorized = error {
                await handleSessionExpired()
                return
            }
            let hadData = dashboard != nil
            hydrateFromLocalStore()
            errorMessage = error.localizedDescription
            // The once-a-minute background refresh fails quietly when the phone is offline. Someone
            // who pulled to refresh, or tapped Refresh Now, is owed an answer.
            if forcingDeviceRefresh, hadData, let message = error.userFacingMessage {
                showNotice("Couldn't refresh, so this is the last saved information. \(message)")
            }
        }
    }

    private var shouldRefreshDeviceData: Bool {
        guard let lastDeviceRefreshAt else { return true }
        return Date().timeIntervalSince(lastDeviceRefreshAt) >= Self.minimumDeviceRefreshInterval
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
            return
        }

        let timezone = household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
        let localDate = DateHelpers.localDateIn(timezone: timezone)
        guard let day = CalendarHelpers.parseLocalDate(localDate, timezone: timezone) else {
            nativeTodayScheduleEvents = []
            return
        }

        var calendar = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn)
        calendar.timeZone = timezone
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
        nativeTodayScheduleEvents = nativeCalendar.scheduleEvents(start: start, end: end)
    }

    func refreshNativeGroceryItems() async {
        guard auth.isSignedIn else { return }
        let session = auth.sessionVersion
        let userId = currentUser?.id
        nativeReminders.refreshAccessStatus()
        guard nativeReminders.hasFullAccess, nativeReminders.selectedListId != nil else {
            nativeGroceryItems = []
            return
        }

        do {
            let items = try await nativeReminders.loadItems()
            guard isCurrentSession(session, userId: userId) else { return }
            nativeGroceryItems = items
        } catch {
            guard isCurrentSession(session, userId: userId) else { return }
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
        guard auth.isSignedIn else { return }
        let session = auth.sessionVersion
        let userId = currentUser?.id
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
            guard isCurrentSession(session, userId: userId) else { return }
            let savedModules = try await api.saveHubModules(modules)
            if isCurrentSession(session, userId: userId), saveVersion == hubModulesSaveVersion {
                pendingHubModulesSave = nil
                applyHubModules(savedModules == modules ? savedModules : modules)
            }
        } catch {
            if isCurrentSession(session, userId: userId), saveVersion == hubModulesSaveVersion {
                pendingHubModulesSave = nil
                errorMessage = error.localizedDescription
                if let message = error.userFacingMessage {
                    showNotice("Your layout change is on this device only; it couldn't be saved. \(message)")
                }
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

    /// True while the signed-in person's email address has not been confirmed. They can still use
    /// everything; this only decides whether to remind them.
    var needsEmailVerification: Bool {
        guard let user = currentUser else { return false }
        return !user.emailVerified
    }

    func sendVerificationEmail() async throws {
        guard let email = currentUser?.email else { return }
        try await auth.sendVerificationEmail(to: email)
    }

    func refreshSession() async {
        let version = auth.sessionVersion
        switch await auth.restoreSession() {
        case .signedIn:
            guard version == auth.sessionVersion else { return }
            localStore.saveUser(auth.currentUser)
        case .signedOut:
            guard version == auth.sessionVersion else { return }
            await handleSessionExpired()
        case .unreachable:
            break
        }
    }

    func signOut() async {
        let notificationCleanup = clearSignedInState()
        await auth.signOut()
        await notificationCleanup.value
        guard !auth.isSignedIn else { return }
        await SleepLiveActivityManager.endAll()
    }

    /// Everything that belongs to the signed-in person, for sign-out and for an ended session.
    @discardableResult
    private func clearSignedInState() -> Task<Void, Never> {
        let notificationCleanup = nativeNotifications.clearSessionReminders()
        _ = NotificationResponder.takePendingDestination()
        dashboardRequestVersion += 1
        householdRequestVersion += 1
        hubModulesSaveVersion += 1
        eventKitRefreshTask?.cancel()
        nativeTodayScheduleEvents = []
        nativeGroceryItems = []
        household = nil
        dashboard = nil
        hubModules = .defaults
        pendingHubModulesSave = nil
        locallySavedHubModules = nil
        setHasAnniversaries(false)
        localStore.clear()
        lastDeviceRefreshAt = nil
        pendingProfileEditId = nil
        pendingFoodSection = nil
        selectedDestination = .dashboard
        return notificationCleanup
    }

    private func hydrateFromLocalStore() {
        if dashboard == nil, let cachedDashboard = localStore.loadDashboard() {
            dashboard = cachedDashboard
            household = cachedDashboard.household
            if let modules = cachedDashboard.hubModules {
                applyHubModules(modules)
            }
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
