import Foundation

struct ChoreGroup: Identifiable {
    let id: String
    let name: String
    let color: String
    let avatar: String
    let chores: [ChoreRow]
}

@MainActor
final class ChoresViewModel: ObservableObject {
    @Published var chores: [ChoreRow] = []
    @Published var profiles: [Profile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingChoreId: String?
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

    var groups: [ChoreGroup] {
        var result = profiles.map { profile in
            ChoreGroup(
                id: profile.id,
                name: profile.name,
                color: profile.color,
                avatar: profile.avatar,
                chores: chores.filter { $0.profileId == profile.id }
            )
        }
        let familyChores = chores.filter { $0.profileId == nil }
        result.append(
            ChoreGroup(
                id: "family",
                name: "Family",
                color: "#4f7c6d",
                avatar: "sparkles",
                chores: familyChores
            )
        )
        return result.filter { !$0.chores.isEmpty || $0.id == "family" }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let choresTask = appState.api.fetchAllChores(localDate: localDate)
            async let profilesTask = appState.api.fetchProfiles()
            chores = try await choresTask
            profiles = try await profilesTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleChore(_ chore: ChoreRow) async {
        guard let appState else { return }
        do {
            try await appState.api.toggleChore(
                ToggleChoreRequest(choreId: chore.id, periodKey: chore.periodKey)
            )
            await load()
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createChore(_ input: ChoreInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.addChore(input)
            showAddForm = false
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateChore(id: String, input: ChoreInput) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.updateChore(id: id, input: input)
            editingChoreId = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteChore(id: String) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.deleteChore(id: id)
            editingChoreId = nil
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
