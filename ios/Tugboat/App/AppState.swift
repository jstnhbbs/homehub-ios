import Combine
import Foundation
import SwiftUI
import WidgetKit

enum AppConfig {
    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "TUGBOAT_API_URL") as? String,
           let url = URL(string: value) {
            return url
        }
        return URL(string: "http://localhost:3000")!
    }
}

@MainActor
final class AppState: ObservableObject {
    let auth: AuthService
    let api: TugboatAPI
    let nativeCalendar: NativeCalendarService
    let nativeReminders: NativeRemindersService
    let nativeNotifications: NativeNotificationService
    let nativeWeather: NativeWeatherService
    let localStore: TugboatLocalStore

    @Published var household: Household?
    @Published var dashboard: DashboardData? { didSet { scheduleWidgetUpdate() } }
    /// Whether the household has any anniversary. Views that show the module's name read
    /// `CelebrationNaming.current`, and observing this makes them redraw when it changes.
    @Published private(set) var hasAnniversaries = CelebrationNaming.hasAnniversaries()
    @Published var nativeTodayScheduleEvents: [ScheduleEvent] = [] { didSet { scheduleWidgetUpdate() } }
    /// The next day's events, for the Large Schedule card.
    @Published var nativeTomorrowScheduleEvents: [ScheduleEvent] = []
    @Published var nativeGroceryItems: [GroceryItem] = [] { didSet { scheduleWidgetUpdate() } }
    @Published var hubModules: HubModules = .defaults { didSet { scheduleWidgetUpdate() } }
    @Published var selectedDestination: HubDestination = .dashboard
    @Published var pendingFoodSection: FoodHubSection?
    @Published var pendingWidgetRecipeId: String?
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
            scheduleWidgetUpdate()
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

    /// The open Settings pages; see `SettingsNavigationModel`.
    let settingsNavigation = SettingsNavigationModel()

    private static let accentStorageKey = "tugboat.accentPalette"
    private static let appearanceModeKey = "tugboat.appearanceMode"
    private static let trueBlackKey = "tugboat.trueBlack"

    private var eventKitObserver: NSObjectProtocol?
    private var dataChangedObserver: NSObjectProtocol?
    private var widgetWriteObserver: NSObjectProtocol?
    private var widgetNetworkWatcher: WidgetNetworkWatcher?
    private let widgetWriteListener = WidgetWriteObserver()
    private var lastSeenWidgetWrite = WidgetWriteSignal.lastWriteAt ?? .distantPast
    /// Goes up when something changed outside the app's own screens (a widget check-off), so pages that
    /// load their own data reload.
    @Published private(set) var externalChangeToken = 0
    private var openDestinationObserver: NSObjectProtocol?
    private var eventKitRefreshTask: Task<Void, Never>?
    private var widgetUpdateTask: Task<Void, Never>?
    private var widgetRecipeTask: Task<Void, Never>?
    private var widgetRecipeId: String?
    private var widgetRecipeFetchedAt: Date?
    private var lastDeviceRefreshAt: Date?
    private var hubModulesSaveVersion = 0
    private var acknowledgedHubModulesVersion = 0
    private var pendingHubModulesPatches: [Int: HubModulesPatch] = [:]
    /// Serialized writes carry only pending edits, so superseded tasks cannot overwrite another device's layout.
    private var hubModulesRequestTail: Task<Void, Never>?
    private var dashboardRequestVersion = 0
    private var householdRequestVersion = 0

    private func isCurrentSession(_ version: Int, userId: String?, includingCancelledWork: Bool = false) -> Bool {
        (includingCancelledWork || !Task.isCancelled) && auth.isSignedIn
            && auth.sessionVersion == version && currentUser?.id == userId
    }

    init(baseURL: URL = AppConfig.baseURL) {
        self.auth = AuthService(baseURL: baseURL)
        self.api = TugboatAPI(baseURL: baseURL)
        self.nativeCalendar = NativeCalendarService()
        self.nativeReminders = NativeRemindersService()
        self.nativeNotifications = NativeNotificationService()
        self.nativeWeather = NativeWeatherService()
        self.localStore = TugboatLocalStore()
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
            forName: .tugboatDataChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshDashboard() }
        }
        // Widget taps made without a connection are sent when the phone gets one back (and when the app comes
        // to the front: `RootView`).
        widgetNetworkWatcher = WidgetNetworkWatcher { [weak self] in
            Task { @MainActor in await self?.flushPendingWidgetActions() }
        }
        // A widget finished a check-off or End Sleep: show it.
        widgetWriteObserver = NotificationCenter.default.addObserver(
            forName: .tugboatWidgetWrote, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshForWidgetWrites() }
        }
        // A tap on a notification opens the page it is about (Routines, Chores, Sleep, Celebrations).
        openDestinationObserver = NotificationCenter.default.addObserver(
            forName: .tugboatOpenDestination, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openPendingNotificationDestination() }
        }
        authObserver = auth.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        widgetUpdateTask?.cancel()
        widgetRecipeTask?.cancel()
        eventKitRefreshTask?.cancel()
        if let eventKitObserver {
            NotificationCenter.default.removeObserver(eventKitObserver)
        }
        if let widgetWriteObserver { NotificationCenter.default.removeObserver(widgetWriteObserver) }
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
            // Show the sign-in screen now. The cleanup below talks to the notification center and Live Activities,
            // and if either is slow to answer (a fresh simulator, a busy phone) the app sat on a spinner until it
            // did.
            isBootstrapping = false
            await notificationCleanup.value
            guard endedSession == auth.sessionVersion else { return }
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
        showNotice("You were signed out. Please sign in again.")
    }

    /// Calendar, Reminders and weather are read from the device, and the system tells us the moment a
    /// calendar or reminder changes (see `observeEventKitChanges`), so re-reading them on every
    /// refresh, which happens after each check-off and every minute, is wasted work. They are read at
    /// most this often unless the person asks (pull to refresh).
    private static let minimumDeviceRefreshInterval: TimeInterval = 5 * 60

    /// A reorder changes no check-offs or reminders, so the save response is enough to update Today.
    func applySavedSnackOrder(household: Household, options: [String]) {
        // An earlier fetch must not put the pre-save order back after this acknowledged write.
        dashboardRequestVersion += 1
        householdRequestVersion += 1
        self.household = household
        guard var updated = dashboard else { return }
        updated.household = household
        updated.snackOptions = options
        dashboard = updated
        localStore.saveDashboard(updated)
    }

    /// Sends the widget taps that were made without a connection, then shows what the server now has.
    func flushPendingWidgetActions() async {
        guard auth.isSignedIn, !WidgetPendingQueue().load().isEmpty else { return }
        await WidgetSync.flush()
        // A refused tap was undone in the widget's data; a sent one changed the server. Either way look again.
        await refreshForWidgetWrites()
    }

    /// A widget wrote something to the server since this app last looked (it runs in another process, so
    /// nothing here changed by itself). Reloads the dashboard and tells the pages that load their own data.
    func refreshForWidgetWrites() async {
        guard let wrote = WidgetWriteSignal.lastWriteAt, wrote > lastSeenWidgetWrite else { return }
        lastSeenWidgetWrite = wrote
        await refreshDashboard()
        externalChangeToken += 1
    }

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
                await refreshNativeWeather(force: forcingDeviceRefresh)
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
            nativeTomorrowScheduleEvents = []
            return
        }

        let timezone = household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
        let localDate = DateHelpers.localDateIn(timezone: timezone)
        guard let day = CalendarHelpers.parseLocalDate(localDate, timezone: timezone) else {
            nativeTodayScheduleEvents = []
            nativeTomorrowScheduleEvents = []
            return
        }

        var calendar = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn)
        calendar.timeZone = timezone
        let start = calendar.startOfDay(for: day)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
        let tomorrowEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: tomorrowStart) ?? tomorrowStart
        nativeTodayScheduleEvents = nativeCalendar.scheduleEvents(start: start, end: end)
        nativeTomorrowScheduleEvents = nativeCalendar.scheduleEvents(start: tomorrowStart, end: tomorrowEnd)
    }

    func refreshNativeGroceryItems() async {
        guard auth.isSignedIn else { return }
        let session = auth.sessionVersion
        let userId = currentUser?.id
        nativeReminders.refreshAccessStatus()
        guard groceriesUseNativeReminders else {
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

    /// True when grocery writes should go to the device Reminders list instead of the API. Allowing Reminders access
    /// on the Groceries page is what opts in, and with no list chosen the device's default list is used, so this
    /// is the permission alone; it used to also need a stored list, which the Groceries page did not, and after a
    /// reinstall (iOS keeps the permission, the app forgets the list) Today and Groceries showed different lists.
    var groceriesUseNativeReminders: Bool {
        nativeReminders.hasFullAccess
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

    func refreshNativeWeather(force: Bool = false) async {
        await nativeWeather.refreshWeather(force: force)
    }

    func applyHubModules(_ modules: HubModules) {
        hubModules = modules
        if dashboard?.hubModules != modules {
            dashboard?.hubModules = modules
            localStore.saveDashboard(dashboard)
        }
        normalizeNavigation()
    }

    @discardableResult
    func saveHubModules(_ modules: HubModules) -> Task<Void, Never> {
        guard auth.isSignedIn else { return Task {} }
        let patch = HubModulesPatch(from: hubModules, to: modules)
        guard !patch.isEmpty else { return Task {} }
        let session = auth.sessionVersion
        let userId = currentUser?.id
        hubModulesSaveVersion += 1
        let saveVersion = hubModulesSaveVersion
        pendingHubModulesPatches[saveVersion] = patch
        let birthdaysWereEnabled = hubModules.isEnabled(.birthdays)
        applyHubModules(modules)
        return Task {
            await persistHubModules(version: saveVersion, session: session, userId: userId,
                                    rescheduleBirthdays: birthdaysWereEnabled != modules.isEnabled(.birthdays))
        }
    }

    private func persistHubModules(version: Int, session: Int, userId: String?, rescheduleBirthdays: Bool) async {
        // The Birthdays module also gates birthday reminders, so re-plan them when it flips.
        if rescheduleBirthdays, isCurrentSession(session, userId: userId, includingCancelledWork: true) {
            await rescheduleNativeNotifications()
        }
        do {
            guard isCurrentSession(session, userId: userId, includingCancelledWork: true),
                  let savedModules = try await sendHubModules(version: version, session: session, userId: userId) else { return }
            guard isCurrentSession(session, userId: userId, includingCancelledWork: true) else { return }
            guard version > acknowledgedHubModulesVersion else { return }
            acknowledgedHubModulesVersion = version
            pendingHubModulesPatches = pendingHubModulesPatches.filter { $0.key > version }
            dashboardRequestVersion += 1
            applyHubModules(preferredHubModules(for: savedModules))
        } catch {
            if isCurrentSession(session, userId: userId, includingCancelledWork: true), version == hubModulesSaveVersion {
                errorMessage = error.localizedDescription
                if let message = error.userFacingMessage {
                    showNotice("Your layout change is on this device only; it couldn't be saved. \(message)")
                }
            }
        }
    }

    /// Newer saves include all unacknowledged edits, including ones skipped or failed earlier.
    private func sendHubModules(version: Int, session: Int, userId: String?) async throws -> HubModules? {
        let previous = hubModulesRequestTail
        let request = Task<Result<HubModules?, Error>, Never> { @MainActor in
            await previous?.value
            guard version == self.hubModulesSaveVersion,
                  self.isCurrentSession(session, userId: userId) else { return .success(nil) }
            let patch = self.pendingHubModulesPatches.keys.sorted().filter { $0 <= version }
                .reduce(HubModulesPatch()) { $0.merging(self.pendingHubModulesPatches[$1] ?? HubModulesPatch()) }
            do {
                return .success(try await self.api.saveHubModules(patch))
            } catch {
                return .failure(error)
            }
        }
        hubModulesRequestTail = Task { _ = await request.value }
        return try await request.value.get()
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
    }

    /// Everything that belongs to the signed-in person, for sign-out and for an ended session.
    @discardableResult
    private func clearSignedInState() -> Task<Void, Never> {
        widgetUpdateTask?.cancel()
        widgetRecipeTask?.cancel()
        widgetRecipeId = nil
        widgetRecipeFetchedAt = nil
        WidgetStore().clear()
        WidgetPendingQueue().clear()
        WidgetCenter.shared.reloadAllTimelines()
        let notificationCleanup = nativeNotifications.clearSessionReminders()
        let activityCleanup = SleepLiveActivityManager.clearSessionActivities()
        _ = NotificationResponder.takePendingDestination()
        dashboardRequestVersion += 1
        householdRequestVersion += 1
        hubModulesSaveVersion += 1
        eventKitRefreshTask?.cancel()
        nativeTodayScheduleEvents = []
        nativeTomorrowScheduleEvents = []
        nativeGroceryItems = []
        household = nil
        dashboard = nil
        hubModules = .defaults
        pendingHubModulesPatches = [:]
        acknowledgedHubModulesVersion = 0
        setHasAnniversaries(false)
        localStore.clear()
        lastDeviceRefreshAt = nil
        pendingProfileEditId = nil
        pendingFoodSection = nil
        pendingWidgetRecipeId = nil
        selectedDestination = .dashboard
        return Task {
            await notificationCleanup.value
            await activityCleanup.value
        }
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

    private func scheduleWidgetUpdate() {
        widgetUpdateTask?.cancel()
        widgetUpdateTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self, self.auth.isSignedIn, SessionCredentials.shared(for: AppConfig.baseURL).hasSession, let dashboard = self.dashboard,
                  let userId = self.currentUser?.id else { return }
            // Server data doesn't have taps still waiting for a connection yet; keep them shown.
            let snapshot = WidgetPendingQueue().overlay(on: WidgetSnapshotBuilder.make(
                dashboard: dashboard, userId: userId, palette: self.accentPalette.rawValue,
                events: self.nativeTodayScheduleEvents,
                groceries: self.groceriesUseNativeReminders ? self.nativeGroceryItems : dashboard.groceryItems,
                modules: self.hubModules
            ))
            if WidgetStore().save(snapshot) { WidgetCenter.shared.reloadAllTimelines() }
            guard let recipeId = snapshot.dinner?.recipeId,
                  recipeId != self.widgetRecipeId || Date().timeIntervalSince(self.widgetRecipeFetchedAt ?? .distantPast) >= 3600 else { return }
            self.widgetRecipeId = recipeId
            self.widgetRecipeFetchedAt = .now
            self.widgetRecipeTask?.cancel()
            let session = self.auth.sessionVersion
            self.widgetRecipeTask = Task { @MainActor [weak self] in
                guard let self, let recipe = try? await self.api.fetchRecipe(id: recipeId), !Task.isCancelled,
                      self.isCurrentSession(session, userId: userId),
                      var latest = WidgetStore().load(), latest.userId == userId,
                      latest.dinner?.recipeId == recipeId else { return }
                latest.dinner?.imageURL = recipe.imageUrl
                if WidgetStore().save(latest) { WidgetCenter.shared.reloadAllTimelines() }
            }
        }
    }

    private func preferredHubModules(for incoming: HubModules) -> HubModules {
        pendingHubModulesPatches.keys.sorted().reduce(incoming) {
            pendingHubModulesPatches[$1]?.applying(to: $0) ?? $0
        }
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
