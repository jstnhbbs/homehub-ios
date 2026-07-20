import Foundation

@MainActor
final class ProfilesViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var selectedProfileId: String?
    @Published var showAddForm = false
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

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var adultProfiles: [Profile] {
        profiles.filter { $0.profileType == .adult }
    }

    var childProfiles: [Profile] {
        profiles.filter { $0.profileType == .child }
    }

    var selectedProfile: Profile? {
        guard let selectedProfileId else { return nil }
        return profiles.first { $0.id == selectedProfileId }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profiles = try await appState.api.fetchProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addProfile(_ input: ProfileInput) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let profile = try await appState.api.addProfile(input)
            showAddForm = false
            selectedProfileId = profile.id
            await load()
            await appState.refreshDashboard()
            successMessage = "Added \(profile.name)."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateProfile(id: String, input: ProfileInput) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let profile = try await appState.api.updateProfile(id: id, input: input)
            selectedProfileId = profile.id
            await load()
            await appState.refreshDashboard()
            if profile.userId == appState.currentUser?.id {
                await appState.refreshSession()
            }
            successMessage = "Saved changes."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
