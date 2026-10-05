import Foundation
import SwiftData

@Model
final class HomeHubLocalSnapshot {
    @Attribute(.unique) var id: String
    var updatedAt: Date
    var householdData: Data?
    var dashboardData: Data?
    /// Who was signed in, so the app can open straight to the saved screens with no connection.
    /// Added later than the rest; a copy saved by an older version simply has none.
    var userData: Data?

    init(
        id: String,
        updatedAt: Date = .now,
        householdData: Data? = nil,
        dashboardData: Data? = nil,
        userData: Data? = nil
    ) {
        self.id = id
        self.updatedAt = updatedAt
        self.householdData = householdData
        self.dashboardData = dashboardData
        self.userData = userData
    }
}

@MainActor
final class HomeHubLocalStore {
    private let container: ModelContainer
    private let context: ModelContext
    private let snapshotId = "current"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let schema = Schema([HomeHubLocalSnapshot.self])
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            LocalStoreLocation.removeLegacyStore(in: support)
            let configuration = ModelConfiguration(schema: schema, url: try LocalStoreLocation.prepare(in: support))
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Including the device being locked when the app starts, which the protected folder
            // refuses: this launch runs without an offline copy.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                preconditionFailure("Could not create SwiftData cache container: \(error.localizedDescription)")
            }
        }

        context = ModelContext(container)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadHousehold() -> Household? {
        guard let data = currentSnapshot()?.householdData else { return nil }
        return try? decoder.decode(Household.self, from: data)
    }

    func loadUser() -> User? {
        guard let data = currentSnapshot()?.userData else { return nil }
        return try? decoder.decode(User.self, from: data)
    }

    func saveUser(_ user: User?) {
        guard let user, let data = try? encoder.encode(user) else { return }
        let snapshot = editableSnapshot()
        guard snapshot.userData != data else { return }
        snapshot.userData = data
        save()
    }

    func loadDashboard() -> DashboardData? {
        guard let data = currentSnapshot()?.dashboardData else { return nil }
        return try? decoder.decode(DashboardData.self, from: data)
    }

    /// Invite codes let whoever holds them into the household, so they are never written to the
    /// offline copy. They come back with the next successful refresh.
    private static func withoutInviteCodes(_ household: Household) -> Household {
        var copy = household
        copy.inviteCode = ""
        copy.guestInviteCode = ""
        return copy
    }

    func saveHousehold(_ household: Household?) {
        guard let household else { return }
        let snapshot = editableSnapshot()
        snapshot.householdData = try? encoder.encode(Self.withoutInviteCodes(household))
        snapshot.updatedAt = .now
        save()
    }

    func saveDashboard(_ dashboard: DashboardData?) {
        guard let dashboard else { return }
        let snapshot = editableSnapshot()
        var stored = dashboard
        stored.household = Self.withoutInviteCodes(dashboard.household)
        snapshot.householdData = try? encoder.encode(stored.household)
        snapshot.dashboardData = try? encoder.encode(stored)
        snapshot.updatedAt = .now
        save()
    }

    func clear() {
        guard let snapshot = currentSnapshot() else { return }
        context.delete(snapshot)
        save()
    }

    private func editableSnapshot() -> HomeHubLocalSnapshot {
        if let snapshot = currentSnapshot() {
            return snapshot
        }

        let snapshot = HomeHubLocalSnapshot(id: snapshotId)
        context.insert(snapshot)
        return snapshot
    }

    private func currentSnapshot() -> HomeHubLocalSnapshot? {
        var descriptor = FetchDescriptor<HomeHubLocalSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.id == snapshotId
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        try? context.save()
    }
}
