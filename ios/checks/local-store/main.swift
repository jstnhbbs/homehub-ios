import Foundation
import SwiftData

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

@MainActor
func run() throws {
    let schema = Schema([HomeHubLocalSnapshot.self])
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("checks.store")
    let configuration = ModelConfiguration(schema: schema, url: url)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = HomeHubLocalStore(container: container)
    func snapshot() throws -> HomeHubLocalSnapshot {
        let reader = ModelContext(container)
        return try reader.fetch(FetchDescriptor<HomeHubLocalSnapshot>()).first!
    }

    check("empty cache loads no data", store.loadUser() == nil && store.loadHousehold() == nil && store.loadDashboard() == nil)
    store.clear()
    var household = Household(id: "h1", name: "Family", timezone: "America/Chicago", weekStartsOn: 1,
                              inviteCode: "parent-secret", guestInviteCode: "guest-secret", snackOptions: "Apple", role: .owner)
    let user = User(id: "u1", name: "Parent", email: "parent@example.com", emailVerified: true)
    store.saveUser(user)
    store.saveHousehold(household)
    check("reads after an initially empty lookup see new data", store.loadUser()?.id == "u1" && store.loadHousehold()?.name == "Family")
    check("household invite codes are stripped", store.loadHousehold()?.inviteCode == "" && store.loadHousehold()?.guestInviteCode == "")
    let initial = try snapshot().updatedAt
    household.inviteCode = "replacement-secret"
    for _ in 0..<100 { store.saveUser(user); store.saveHousehold(household) }
    check("unchanged household refreshes do not rewrite the snapshot", try snapshot().updatedAt == initial)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let householdData = try encoder.encode(household)
    let householdObject = try JSONSerialization.jsonObject(with: householdData)
    let fixture = try JSONSerialization.data(withJSONObject: ["household": householdObject, "localDate": "2026-10-07"])
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var dashboard = try decoder.decode(DashboardData.self, from: fixture)
    dashboard.notes = (0..<500).map {
        HouseholdNote(id: "n\($0)", title: "Note \($0)", body: String(repeating: "Saved family data. ", count: 30), color: "sage", pinned: true)
    }
    store.saveDashboard(dashboard)
    let dashboardDate = try snapshot().updatedAt
    let dashboardBytes = try snapshot().dashboardData
    let start = Date()
    for _ in 0..<100 { store.saveDashboard(dashboard) }
    print(String(format: "100 equal dashboard saves (500 notes): %.1f ms", Date().timeIntervalSince(start) * 1000))
    check("equal dashboard refreshes keep the timestamp and bytes", try snapshot().updatedAt == dashboardDate && snapshot().dashboardData == dashboardBytes)
    check("both dashboard invite codes stay redacted", store.loadDashboard()?.household.inviteCode == "" && store.loadDashboard()?.household.guestInviteCode == "")
    check("dashboard save preserves the signed-in user", store.loadUser()?.id == user.id)

    if CommandLine.arguments.contains("--benchmark") {
        let baselineURL = url.deletingLastPathComponent().appendingPathComponent("baseline.store")
        let baselineContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: baselineURL)])
        let context = ModelContext(baselineContainer)
        context.autosaveEnabled = false
        var redacted = dashboard
        redacted.household.inviteCode = ""
        redacted.household.guestInviteCode = ""
        // Reproduce the previous refresh path: fetch, encode, update timestamp, save every time.
        let start = Date()
        for _ in 0..<100 {
            var fetch = FetchDescriptor<HomeHubLocalSnapshot>(predicate: #Predicate { $0.id == "current" })
            fetch.fetchLimit = 1
            let existing = try context.fetch(fetch).first
            let snapshot = existing ?? HomeHubLocalSnapshot(id: "current")
            if existing == nil { context.insert(snapshot) }
            snapshot.householdData = try encoder.encode(redacted.household)
            snapshot.dashboardData = try encoder.encode(redacted)
            snapshot.updatedAt = .now
            try context.save()
        }
        print(String(format: "100 saves reproducing previous path (500 notes): %.1f ms", Date().timeIntervalSince(start) * 1000))
    }

    dashboard.notes[0].title = "Changed remotely"
    dashboard.household.name = "Renamed family"
    store.saveDashboard(dashboard)
    let reopened = HomeHubLocalStore(container: try ModelContainer(for: schema, configurations: [configuration]))
    check("changed data is on disk immediately", reopened.loadDashboard()?.notes.first?.title == "Changed remotely" && reopened.loadHousehold()?.name == "Renamed family")
    check("user persists alongside dashboard after reopening", reopened.loadUser()?.id == user.id)

    store.saveDashboard(nil)
    store.saveHousehold(nil)
    store.saveUser(nil)
    check("nil refresh inputs preserve the offline copy", store.loadDashboard()?.notes.count == 500 && store.loadUser()?.id == user.id)

    store.clear()
    check("sign-out clears all cached data", store.loadUser() == nil && store.loadHousehold() == nil && store.loadDashboard() == nil)
    let cleared = HomeHubLocalStore(container: try ModelContainer(for: schema, configurations: [configuration]))
    check("sign-out also clears the disk copy", cleared.loadUser() == nil && cleared.loadDashboard() == nil)
    let nextUser = User(id: "u2", name: "Next parent", email: "next@example.com", emailVerified: false)
    store.saveUser(nextUser)
    store.saveDashboard(dashboard)
    check("new sign-in can create a snapshot after clearing", store.loadUser()?.id == "u2" && store.loadDashboard()?.notes.count == 500)
    let count = try ModelContext(container).fetchCount(FetchDescriptor<HomeHubLocalSnapshot>())
    check("clear then save leaves exactly one snapshot", count == 1)
}

do { try MainActor.assumeIsolated { try run() } }
catch { failures += 1; print("FAIL \(error)") }
if failures > 0 { exit(1) }
