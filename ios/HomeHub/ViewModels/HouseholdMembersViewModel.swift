import Foundation

@MainActor
final class HouseholdMembersViewModel: ObservableObject {
    @Published var members: [HouseholdMemberSummary] = []
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    func load() async {
        guard let appState, canManage else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            members = try await appState.api.fetchHouseholdMembers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeGuest(userId: String) async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            try await appState.api.removeGuestMember(userId: userId)
            await load()
            successMessage = "Guest removed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
