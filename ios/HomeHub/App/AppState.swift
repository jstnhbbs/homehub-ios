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

    @Published var household: Household?
    @Published var dashboard: DashboardData?
    @Published var selectedDestination: HubDestination = .dashboard
    @Published var pendingProfileEditId: String?
    @Published var isBootstrapping = true
    @Published var errorMessage: String?

    init(baseURL: URL = AppConfig.baseURL) {
        self.auth = AuthService(baseURL: baseURL)
        self.api = HomeHubAPI(baseURL: baseURL)
    }

    var needsOnboarding: Bool {
        auth.isSignedIn && household == nil
    }

    var canManageHousehold: Bool {
        guard let role = household?.role else { return false }
        return HouseholdRoles.canManageHousehold(role: role)
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
        await auth.restoreSession()
        guard auth.isSignedIn else {
            household = nil
            dashboard = nil
            return
        }
        await refreshHousehold()
    }

    func refreshHousehold() async {
        do {
            household = try await api.fetchHousehold()
            if household != nil {
                await refreshDashboard()
            } else {
                dashboard = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshDashboard() async {
        do {
            dashboard = try await api.fetchDashboard()
            household = dashboard?.household
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSession() async {
        await auth.restoreSession()
    }

    func signOut() async {
        await auth.signOut()
        household = nil
        dashboard = nil
        pendingProfileEditId = nil
        selectedDestination = .dashboard
    }
}
