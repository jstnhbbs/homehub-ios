import Foundation
import SwiftData

@Model
final class HomeHubLocalSnapshot {
    @Attribute(.unique) var id: String
    var updatedAt: Date
    var householdData: Data?
    var dashboardData: Data?

    init(id: String, updatedAt: Date = .now, householdData: Data? = nil, dashboardData: Data? = nil) {
        self.id = id
        self.updatedAt = updatedAt
        self.householdData = householdData
        self.dashboardData = dashboardData
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
        let configuration = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
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

    func loadDashboard() -> DashboardData? {
        guard let data = currentSnapshot()?.dashboardData else { return nil }
        return try? decoder.decode(DashboardData.self, from: data)
    }

    func saveHousehold(_ household: Household?) {
        guard let household else { return }
        let snapshot = editableSnapshot()
        snapshot.householdData = try? encoder.encode(household)
        snapshot.updatedAt = .now
        save()
    }

    func saveDashboard(_ dashboard: DashboardData?) {
        guard let dashboard else { return }
        let snapshot = editableSnapshot()
        snapshot.householdData = try? encoder.encode(dashboard.household)
        snapshot.dashboardData = try? encoder.encode(dashboard)
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
