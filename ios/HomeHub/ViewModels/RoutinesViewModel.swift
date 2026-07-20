import Foundation

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

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var localDate: String {
        guard let appState,
              let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) else {
            return DateHelpers.localDateIn(timezone: .current)
        }
        return DateHelpers.localDateIn(timezone: timezone)
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

        do {
            async let routinesTask = appState.api.fetchRoutines()
            async let profilesTask = appState.api.fetchProfiles()
            routines = try await routinesTask
            profiles = try await profilesTask
            await refreshCompletedSteps()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshCompletedSteps() async {
        guard let appState else { return }
        if appState.dashboard == nil {
            await appState.refreshDashboard()
        }
        completedStepIds = Set(
            (appState.dashboard?.routineSteps ?? [])
                .filter(\.completed)
                .map(\.id)
        )
    }

    func toggleStep(_ stepId: String) async {
        guard let appState else { return }
        do {
            try await appState.api.toggleRoutineStep(
                ToggleRoutineStepRequest(stepId: stepId, localDate: localDate)
            )
            if completedStepIds.contains(stepId) {
                completedStepIds.remove(stepId)
            } else {
                completedStepIds.insert(stepId)
            }
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createRoutine(_ input: RoutineInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.addRoutine(input)
            showAddForm = false
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateRoutine(id: String, input: RoutineInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.updateRoutine(id: id, input: input)
            editingRoutineId = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteRoutine(id: String) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.deleteRoutine(id: id)
            editingRoutineId = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func pendingSteps(for routine: Routine) -> [RoutineStep] {
        (routine.steps ?? []).filter { !completedStepIds.contains($0.id) }
    }
}
