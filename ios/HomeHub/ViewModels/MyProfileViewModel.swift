import Foundation

@MainActor
final class MyProfileViewModel: ObservableObject {
    @Published var account: AccountData?
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            account = try await appState.api.fetchAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateName(_ name: String) async -> Bool {
        guard let appState else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            account = try await appState.api.updateAccountName(trimmed)
            await appState.refreshSession()
            await appState.refreshDashboard()
            successMessage = "Name updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateProfile(_ input: ProfileInput) async -> Bool {
        guard let appState, let profile = account?.profile else { return false }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            _ = try await appState.api.updateProfile(id: profile.id, input: input)
            account = try await appState.api.fetchAccount()
            await appState.refreshSession()
            await appState.refreshDashboard()
            successMessage = "Profile updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changeEmail(_ newEmail: String) async -> Bool {
        guard let appState else { return false }
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let response = try await appState.api.changeEmail(trimmed)
            if let user = response.user {
                account = AccountData(user: user, profile: account?.profile)
            }
            await appState.refreshSession()
            successMessage = "Email updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        guard let appState else { return false }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let response = try await appState.api.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            if let user = response.user {
                account = AccountData(user: user, profile: account?.profile)
            }
            await appState.refreshSession()
            successMessage = "Password updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
