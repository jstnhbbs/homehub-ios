import Foundation
import Combine

// Stand-ins for EventKit and HTTP; the check compiles the real GroceriesViewModel.
struct GroceryItem: Identifiable { var id: String; var title: String; var checked = false; var checkedAt: Date? }
struct ReminderListOption { var id: String }
enum NativeRemindersAccessStatus { case authorized, notDetermined, denied, restricted }
enum NativeCalendarPreferenceKeys { static let automaticId = "auto" }
struct GroceryItemInput { var title: String; var category: String? }
enum GroceryHelpers {
    static func sortedItems(_ items: [GroceryItem]) -> [GroceryItem] { items }
    static func groupedItems(_ items: [GroceryItem]) -> [(category: String, items: [GroceryItem])] { [] }
}
extension Error { var userFacingMessage: String? { self is CancellationError ? nil : localizedDescription } }
struct Person { var id = "user" }
struct Household { var id = "home" }
final class Auth { var sessionVersion = 1; var isSignedIn = true }
@MainActor final class FakeReminders {
    var accessStatus = NativeRemindersAccessStatus.authorized
    var hasFullAccess: Bool { accessStatus == .authorized }
    var selectedListId: String? = "A"
    var usesAutomaticList = false
    var block = false
    var failLoads = false
    var writes = 0
    var revision = 0
    var gates: [String: CheckedContinuation<[GroceryItem], Error>] = [:]
    func refreshAccessStatus() {}
    func reminderLists() -> [ReminderListOption] { [] }
    func requestFullAccess() async {}
    func loadItems() async throws -> [GroceryItem] {
        if failLoads { throw CancellationError() }
        guard block else { return [] }
        let id = selectedListId!
        return try await withCheckedThrowingContinuation { gates[id] = $0 }
    }
    func addItem(title: String) throws -> GroceryItem { writes += 1; return .init(id: title, title: title) }
    func setCompleted(itemId: String, completed: Bool) throws { writes += 1 }
    func deleteItem(itemId: String) throws { writes += 1 }
}
@MainActor final class FakeAPI {
    var writes = 0
    func fetchGroceryItems() async throws -> [GroceryItem] { [] }
    func addGroceryItem(_ input: GroceryItemInput) async throws -> GroceryItem { writes += 1; return .init(id: input.title, title: input.title) }
    func toggleGroceryItem(id: String, checked: Bool) async throws -> GroceryItem { writes += 1; return .init(id: id, title: id, checked: checked) }
    func deleteGroceryItem(id: String) async throws { writes += 1 }
    func clearCheckedGroceryItems() async throws { writes += 1 }
}
@MainActor final class AppState {
    let nativeReminders = FakeReminders()
    let api = FakeAPI()
    let auth = Auth()
    var currentUser: Person? = Person()
    var household: Household? = Household()
    var nativeGroceryItems: [GroceryItem] = []
    var canManageHousehold = true
    func refreshDashboard() async {}
    func report(_ error: Error) {}
}
var failures = 0
func check(_ label: String, _ value: Bool) {
    if value { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
@MainActor func until(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(1))
    }
    check("operation reached expected gate", false)
}
@main struct Checks {
    @MainActor static func main() async {
        do {
            let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
            app.nativeReminders.block = true
            let first = Task { await model.load() }
            await until { app.nativeReminders.gates["A"] != nil }
            model.selectReminderList(id: "B")
            await until { app.nativeReminders.gates["B"] != nil }
            app.nativeReminders.gates["B"]!.resume(returning: [.init(id: "B", title: "List B")])
            await until { model.items.first?.id == "B" }
            app.nativeReminders.gates["A"]!.resume(returning: [.init(id: "A", title: "List A")])
            await first.value
            check("late list A cannot replace selected list B", model.items.first?.id == "B")
            check("Today also keeps the selected list B", app.nativeGroceryItems.first?.id == "B")
        }
        do {
            let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
            app.nativeReminders.block = true
            let load = Task { await model.load() }
            await until { app.nativeReminders.gates["A"] != nil }
            app.auth.sessionVersion += 1; app.auth.isSignedIn = false
            app.nativeReminders.gates["A"]!.resume(returning: [.init(id: "old", title: "Old account")])
            await load.value
            check("sign-out discards a pending EventKit load", model.items.isEmpty && app.nativeGroceryItems.isEmpty)
        }
        for native in [true, false] {
            for role in ["owner", "parent", "guest"] {
                let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
                app.canManageHousehold = role != "guest"
                app.nativeReminders.accessStatus = native ? .authorized : .denied
                model.newItemTitle = "Milk"
                await model.addItem()
                let item = GroceryItem(id: "milk", title: "Milk", checked: true)
                model.items = [item]
                await model.toggle(item)
                await model.delete(item)
                model.items = [item]
                await model.clearChecked()
                let count = native ? app.nativeReminders.writes : app.api.writes
                check("\(role) has correct write access with \(native ? "Reminders" : "server")", count == (role == "guest" ? 0 : 4))
            }
        }
        do {
            let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
            app.nativeReminders.block = true
            let load = Task { await model.load() }
            await until { app.nativeReminders.gates["A"] != nil }
            // Another screen wrote to the same EventKit store while this read was pending.
            app.nativeReminders.revision += 1
            app.nativeReminders.block = false
            app.nativeReminders.gates["A"]!.resume(returning: [.init(id: "stale", title: "Before the edit")])
            await load.value
            check("a write from another screen invalidates an older Reminders read", model.items.isEmpty && app.nativeGroceryItems.isEmpty)
        }
        do {
            let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
            app.nativeReminders.block = true
            let load = Task { await model.load() }
            await until { app.nativeReminders.gates["A"] != nil }
            app.nativeReminders.block = false
            model.newItemTitle = "New"
            await model.addItem()
            app.nativeReminders.gates["A"]!.resume(returning: [.init(id: "stale", title: "Stale")])
            await load.value
            check("a read from before a write cannot restore stale items", model.items.isEmpty)
        }
        do {
            let app = AppState(); let model = GroceriesViewModel(); model.bind(to: app)
            app.nativeReminders.failLoads = true
            let item = GroceryItem(id: "milk", title: "Milk")
            model.items = [item]
            await model.toggle(item)
            check("a cancelled reconciliation cannot undo a committed native check-off", model.items.first?.checked == true && app.nativeGroceryItems.first?.checked == true)
            model.newItemTitle = "Eggs"
            await model.addItem()
            check("a cancelled reconciliation cannot turn a committed Add into a failure", model.items.contains { $0.title == "Eggs" } && model.newItemTitle.isEmpty)
        }
        if failures > 0 { exit(1) }
        print("all passed")
    }
}
