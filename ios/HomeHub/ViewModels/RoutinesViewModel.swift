import Foundation
import Combine

@MainActor
final class RoutinesViewModel: ObservableObject {
    @Published var routines: [Routine] = []
    @Published var profiles: [Profile] = []
    @Published var completedStepIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingRoutineId: String?
    @Published var showAddForm = false

    private var appState: AppState?
    private var dashboardSubscription: AnyCancellable?
    private var completionDates: [String: String] = [:]

    func bind(to appState: AppState) {
        guard self.appState !== appState else { return }
        self.appState = appState
        dashboardSubscription = appState.$dashboard.sink { [weak self] dashboard in
            self?.syncCompletedSteps(from: dashboard)
        }
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    /// The routines by person, for the page.
    var groups: [RoutineGroup] {
        RoutineGrouping.groups(routines: routines, profiles: profiles)
    }

    /// The household's first day of the week, for laying out the day chips.
    var weekStartsOn: Int {
        WeekStart.parseWeekStartsOn(appState?.household?.weekStartsOn)
    }

    var localDate: String {
        guard let appState,
              let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) else {
            return DateHelpers.localDateIn(timezone: .current)
        }
        return DateHelpers.localDateIn(timezone: timezone)
    }

    /// The streak for a routine's profile (nil for shared routines), from the latest dashboard load.
    func streak(for profileId: String?) -> RoutineStreak? {
        appState?.dashboard?.routineStreaks.first { $0.profileId == profileId }
    }

    func profile(for id: String?) -> Profile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        await refreshCompletedSteps()

        do {
            async let routinesTask = appState.api.fetchRoutines()
            async let profilesTask = appState.api.fetchProfiles()
            routines = try await routinesTask
            profiles = try await profilesTask
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    private func refreshCompletedSteps() async {
        guard let appState else { return }
        await appState.refreshDashboard()
        syncCompletedSteps(from: appState.dashboard)
    }

    private func syncCompletedSteps(from dashboard: DashboardData?) {
        if dashboard == nil { completionDates = [:] }
        completedStepIds = Set(
            (dashboard?.localDate == localDate ? dashboard?.routineSteps ?? [] : [])
                .filter(\.completed)
                .map(\.id)
        )
    }

    /// Steps are only checked off from the list, never unchecked, so the wanted state is "done".
    func toggleStep(_ stepId: String) async -> Bool {
        guard let appState else { return false }
        let date = localDate
        let session = appState.auth.sessionVersion
        do {
            // Refresh after the row's celebration, rather than remove it halfway through.
            try await appState.toggleRoutineStep(stepId: stepId, localDate: date, completed: true, refreshingDashboard: false)
            guard session == appState.auth.sessionVersion else { return false }
            completionDates[stepId] = date
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    /// Steps already done today with who did them and when, for the "Done today" list.
    func completedSteps(for routine: Routine) -> [(step: RoutineStep, caption: String?)] {
        guard let appState, appState.dashboard?.localDate == localDate else { return [] }
        let timezone = appState.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
        let rows = Dictionary(
            (appState.dashboard?.routineSteps ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return (routine.steps ?? []).compactMap { step in
            guard let row = rows[step.id], row.completed else { return nil }
            return (
                step,
                CompletionHelpers.caption(name: row.completedByName, completedAt: row.completedAt, timezone: timezone)
            )
        }
    }

    func markStepCompleted(_ stepId: String) {
        guard let appState, let date = completionDates.removeValue(forKey: stepId) else { return }
        if date == localDate { completedStepIds.insert(stepId) }
        Task { await appState.refreshDashboard() }
    }

    func createRoutine(_ input: RoutineInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.addRoutine(input)
            showAddForm = false
            await load()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func updateRoutine(id: String, input: RoutineInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.updateRoutine(id: id, input: input)
            editingRoutineId = nil
            await load()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func deleteRoutine(id: String) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.deleteRoutine(id: id)
            editingRoutineId = nil
            await load()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func pendingSteps(for routine: Routine) -> [RoutineStep] {
        (routine.steps ?? []).filter { !completedStepIds.contains($0.id) }
    }
}
