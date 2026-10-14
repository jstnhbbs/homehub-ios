import Foundation
import Combine

struct Household { var timezone = "America/Chicago"; var weekStartsOn = 1 }
struct DashboardData {
    var localDate: String
    var snackOptions = ["Apple"]
    var snackEaten: [String] = []
    var snackCompletions: [SnackEatenRecord] = []
    var snacksPerChild = false
    var profiles: [Profile] = []
}
enum NapHelpers {
    static func childProfiles(from profiles: [Profile]) -> [Profile] { profiles.filter { $0.profileType == .child } }
}
final class StubAuth { var sessionVersion = 1 }
extension Error { var userFacingMessage: String? { self is CancellationError ? nil : localizedDescription } }

@MainActor
final class StubAPI {
    var meals: [Meal] = []
    var blockSaves = false
    var saveGate: CheckedContinuation<Void, Never>?
    var events: [String] = []
    var resetDate: String?
    var savedSnackOptions: String?
    var failSnackSave = false
    var blockSnackSaves = false
    var snackSaveGate: CheckedContinuation<Void, Never>?
    func fetchMeals(weekStart: String) async throws -> [Meal] {
        let end = MealPlanHelpers.date(weekStart, adding: 6, timezone: TimeZone(identifier: "America/Chicago")!)
        return meals.filter { $0.localDate >= weekStart && $0.localDate <= end }
    }
    func fetchRecipes() async throws -> [Recipe] { [] }
    func saveMeal(_ input: SaveMealRequest) async throws {
        events.append("save-started")
        if blockSaves { await withCheckedContinuation { saveGate = $0 } }
        meals.removeAll { $0.localDate == input.localDate && $0.slot == input.slot }
        meals.append(Meal(localDate: input.localDate, slot: input.slot, title: input.title))
        events.append("save-finished")
    }
    func moveMeal(_ input: MoveMealRequest) async throws -> MoveMealResponse { .init(meals: []) }
    func clearMealWeek(weekStart: String) async throws { events.append("cleared"); meals = [] }
    func copyPreviousMealWeek(weekStart: String) async throws { events.append("copied") }
    func fetchGroceryItems() async throws -> [GroceryItem] { [] }
    func addGroceryItem(_ input: GroceryItemInput) async throws -> GroceryItem {
        .init(id: "g", householdId: nil, title: input.title, quantity: nil, category: "", checked: false,
              checkedAt: nil, sortOrder: 0, createdAt: nil, updatedAt: nil)
    }
    func saveSnackOptions(_ input: SaveSnackOptionsRequest) async throws -> Household {
        if blockSnackSaves { await withCheckedContinuation { snackSaveGate = $0 } }
        if failSnackSave { throw NSError(domain: "SnackSave", code: 1) }
        savedSnackOptions = input.snackOptions
        return Household()
    }
    func resetSnackChecklist(localDate: String) async throws { resetDate = localDate }
}
@MainActor
final class StubReminders {
    var hasFullAccess = false
    func refreshAccessStatus() {}
    func loadItems() async throws -> [GroceryItem] { [] }
    func addItems(_ titles: [String]) throws -> Int { titles.count }
}
@MainActor
final class AppState: ObservableObject {
    @Published var dashboard: DashboardData?
    var household: Household? = Household()
    let api = StubAPI()
    let auth = StubAuth()
    let nativeReminders = StubReminders()
    var canManageHousehold = true
    var snackDate: String?
    var snackCompleted: Bool?
    var dashboardRefreshes = 0
    func refreshDashboard() async { dashboardRefreshes += 1 }
    func applySavedSnackOrder(household: Household, options: [String]) {
        self.household = household
        dashboard?.snackOptions = options
    }
    func refreshNativeGroceryItems() async {}
    func toggleSnack(localDate: String, label: String, profileId: String?, completed: Bool?) async throws {
        snackDate = localDate
        snackCompleted = completed
    }
}

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
@MainActor
func until(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(1))
    }
    check("operation reached its gate", false)
}

@MainActor
func run() async {
    let app = AppState()
    var clock = ISO8601DateFormatter().date(from: "2026-10-13T04:59:00Z")!
    var waitForDrop = false
    var dropGate: CheckedContinuation<Void, Never>?
    let snacks = SnacksViewModel(now: { clock }, waitForDropAnimation: {
        if waitForDrop { await withCheckedContinuation { dropGate = $0 } }
    })
    snacks.bind(to: app)
    app.dashboard = DashboardData(localDate: "2026-10-12", snackEaten: ["Apple"])
    check("the old day's completion is visible before midnight", snacks.eaten == ["Apple"])
    clock = ISO8601DateFormatter().date(from: "2026-10-13T05:01:00Z")!
    await snacks.toggleSnack("Apple", completed: false)
    check("a tap uses today's household date without a network refresh", app.snackDate == "2026-10-13")
    check("yesterday's checked circle cannot uncheck the new day", app.snackCompleted == true)
    check("old cached completions are not reapplied after the tap", snacks.eaten.isEmpty && snacks.localDate == "2026-10-13")
    await snacks.resetChecklist()
    check("reset also targets the current day", app.api.resetDate == "2026-10-13")
    app.dashboard = DashboardData(localDate: "2026-10-13", snackEaten: ["Apple"])
    check("remote updates on the current day are still observed", snacks.eaten == ["Apple"])

    app.dashboard = DashboardData(localDate: "2026-10-13", snackOptions: ["Apple", "Banana", "Crackers"], snackEaten: ["Apple"])
    check("the editable list keeps saved order even for eaten snacks", snacks.displayedSnacks == ["Apple", "Banana", "Crackers"])
    app.api.blockSnackSaves = true
    waitForDrop = true
    let refreshesBeforeDrop = app.dashboardRefreshes
    let reorder = snacks.reorderSnacks(from: IndexSet(integer: 0), to: 3)
    check("native move callback changes the order synchronously", snacks.snackOptions == ["Banana", "Crackers", "Apple"])
    check("saving is reserved before another move can start", snacks.isWorking)
    await until { dropGate != nil }
    check("network save waits for the drop animation", app.api.snackSaveGate == nil && app.api.savedSnackOptions == nil)
    waitForDrop = false
    dropGate?.resume()
    await until { app.api.snackSaveGate != nil }
    check("a drag updates order immediately", snacks.snackOptions == ["Banana", "Crackers", "Apple"])
    app.dashboard = DashboardData(localDate: "2026-10-13", snackOptions: ["Apple", "Banana", "Crackers"], snackEaten: ["Banana"])
    check("refresh during save preserves order but updates check-offs", snacks.snackOptions == ["Banana", "Crackers", "Apple"] && snacks.eaten == ["Banana"])
    await snacks.moveSnack("Crackers", onto: "Banana")
    check("another drag is blocked while saving", snacks.snackOptions == ["Banana", "Crackers", "Apple"])
    app.api.snackSaveGate?.resume()
    app.api.snackSaveGate = nil
    await reorder?.value
    check("chosen order is persisted", app.api.savedSnackOptions == "Banana\nCrackers\nApple")
    check("a reorder does not perform a full dashboard refresh", app.dashboardRefreshes == refreshesBeforeDrop)
    check("Today receives the saved order", app.dashboard?.snackOptions == ["Banana", "Crackers", "Apple"])
    check("a cached dashboard cannot undo a successful save", snacks.snackOptions == ["Banana", "Crackers", "Apple"])
    app.api.blockSnackSaves = false
    app.api.failSnackSave = true
    await snacks.shiftSnack("Apple", by: -1)
    check("failed reorder restores the previous order and shows an error", snacks.snackOptions == ["Banana", "Crackers", "Apple"] && snacks.errorMessage != nil)
    app.api.failSnackSave = false
    app.canManageHousehold = false
    await snacks.moveSnack("Apple", onto: "Banana")
    check("guests cannot reorder snacks", snacks.snackOptions == ["Banana", "Crackers", "Apple"])
    app.canManageHousehold = true
    await snacks.moveSnack("Missing", onto: "Banana")
    check("a stale drag cannot remove or duplicate a snack", snacks.snackOptions == ["Banana", "Crackers", "Apple"])

    let departing = AppState()
    var departingDropGate: CheckedContinuation<Void, Never>?
    let departingSnacks = SnacksViewModel(now: { clock }, waitForDropAnimation: {
        await withCheckedContinuation { departingDropGate = $0 }
    })
    departingSnacks.bind(to: departing)
    departing.dashboard = DashboardData(localDate: "2026-10-13", snackOptions: ["Apple", "Banana"])
    let departingSave = departingSnacks.reorderSnacks(from: IndexSet(integer: 0), to: 2)
    await until { departingDropGate != nil }
    departing.auth.sessionVersion += 1
    departingDropGate?.resume()
    await departingSave?.value
    check("a delayed reorder cannot save across sign-out", departing.api.savedSnackOptions == nil && !departingSnacks.isWorking)

    for bulk in ["clear", "copy"] {
        let state = AppState()
        let model = MealsViewModel()
        model.bind(to: state)
        state.api.blockSaves = true
        let save = Task { await model.setMeal(localDate: model.weekStart, slot: .dinner, title: "Pasta") }
        await until { state.api.saveGate != nil }
        let action = Task { if bulk == "clear" { await model.clearWeek() } else { await model.copyPreviousWeek() } }
        await until { model.isWorking }
        check("\(bulk) waits for the pending save", state.api.events == ["save-started"])
        await model.setMeal(localDate: model.weekStart, slot: .lunch, title: "New edit")
        check("new edits are blocked during \(bulk)", state.api.events == ["save-started"])
        state.api.saveGate?.resume()
        state.api.saveGate = nil
        await save.value
        await action.value
        check("\(bulk) happens after the write finishes", state.api.events == ["save-started", "save-finished", bulk == "clear" ? "cleared" : "copied"])
        if bulk == "clear" { check("no meal reappears after clearing", state.api.meals.isEmpty && model.meals.isEmpty) }
    }

    let state = AppState()
    let model = MealsViewModel()
    model.bind(to: state)
    state.api.blockSaves = true
    let nextWeek = MealPlanHelpers.date(model.weekStart, adding: 7, timezone: model.timezone)
    state.api.meals = [Meal(localDate: nextWeek, slot: .dinner, title: "Next week's meal")]
    let save = Task { await model.setMeal(localDate: model.weekStart, slot: .dinner, title: "Pasta") }
    await until { state.api.saveGate != nil }
    await model.changeWeek(by: 1)
    state.api.saveGate?.resume()
    await save.value
    await until { model.meals.contains { $0.title == "Next week's meal" } }
    check("changing weeks during a save still reloads the new week", model.meals.count == 1)

    let leaving = AppState()
    let leavingModel = MealsViewModel()
    leavingModel.bind(to: leaving)
    leaving.api.blockSaves = true
    let oldSave = Task { await leavingModel.setMeal(localDate: leavingModel.weekStart, slot: .dinner, title: "Pasta") }
    await until { leaving.api.saveGate != nil }
    let oldClear = Task { await leavingModel.clearWeek() }
    await until { leavingModel.isWorking }
    leaving.auth.sessionVersion += 1
    leaving.api.saveGate?.resume()
    await oldSave.value
    await oldClear.value
    check("a clear waiting across sign-out cannot run for the new session", leaving.api.events == ["save-started", "save-finished"])

    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}
Task { await run() }
RunLoop.main.run()
