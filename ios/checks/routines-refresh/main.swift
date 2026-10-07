import Foundation
import Combine

struct Household { var timezone = "America/Chicago"; var weekStartsOn = 1 }
struct RoutineStreak { var profileId: String?; var current: Int }
struct DashboardData {
    var localDate: String
    var routineSteps: [RoutineStepRow]
    var routineStreaks: [RoutineStreak] = []
}
final class Auth { var sessionVersion = 1 }
extension Error {
    var userFacingMessage: String? { self is CancellationError ? nil : localizedDescription }
}

let routine = Routine(id: "r1", householdId: "h1", profileId: nil, name: "Morning", period: .morning,
                      days: "0,1,2,3,4,5,6", sortOrder: 0, steps: [
                        RoutineStep(id: "s1", routineId: "r1", label: "Brush teeth", sortOrder: 0)
                      ])
@MainActor
final class StubAPI {
    func fetchRoutines() async throws -> [Routine] { [routine] }
    func fetchProfiles() async throws -> [Profile] { [] }
    func addRoutine(_ input: RoutineInput) async throws -> Routine { routine }
    func updateRoutine(id: String, input: RoutineInput) async throws -> Routine { routine }
    func deleteRoutine(id: String) async throws {}
}
@MainActor
final class AppState: ObservableObject {
    @Published var dashboard: DashboardData?
    var household: Household? = Household()
    let api = StubAPI()
    let auth = Auth()
    var canManageHousehold = true
    var refreshes = 0
    var nextDashboard: DashboardData?
    var toggleRequests: [Bool] = []
    var duringToggle: (() -> Void)?
    func refreshDashboard() async {
        refreshes += 1
        if let nextDashboard { dashboard = nextDashboard }
    }
    func toggleRoutineStep(stepId: String, localDate: String, completed: Bool?, refreshingDashboard: Bool) async throws {
        toggleRequests.append(refreshingDashboard)
        duringToggle?()
        if refreshingDashboard { await refreshDashboard() }
    }
}

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
func snapshot(completed: Bool, date: String) -> DashboardData {
    DashboardData(localDate: date, routineSteps: [
        RoutineStepRow(id: "s1", label: "Brush teeth", routineName: "Morning", period: .morning,
                      profileId: nil, completed: completed, completedAt: completed ? .now : nil,
                      completedByName: completed ? "Parent" : nil)
    ])
}

@MainActor
func run() async {
    let app = AppState()
    let model = RoutinesViewModel()
    model.bind(to: app)
    let today = model.localDate
    app.dashboard = snapshot(completed: false, date: today)
    model.routines = [routine]
    check("unfinished step is visible", model.pendingSteps(for: routine).count == 1)
    app.dashboard = snapshot(completed: true, date: today)
    check("a remote check-off removes the pending row", model.pendingSteps(for: routine).isEmpty)
    check("and updates Done today", model.completedSteps(for: routine).count == 1)
    app.dashboard = snapshot(completed: false, date: today)
    check("a remote reset restores the step", model.pendingSteps(for: routine).count == 1)
    app.dashboard = snapshot(completed: true, date: "2000-01-01")
    check("yesterday's saved completions do not hide today's steps", model.pendingSteps(for: routine).count == 1)
    check("nor appear as Done today", model.completedSteps(for: routine).isEmpty)

    app.nextDashboard = snapshot(completed: true, date: today)
    await model.load()
    check("pull to refresh fetches completions even with an existing dashboard", app.refreshes == 1 && model.pendingSteps(for: routine).isEmpty)
    app.dashboard = snapshot(completed: false, date: today)
    let toggled = await model.toggleStep("s1")
    check("local success preserves the celebration until it finishes", toggled && model.pendingSteps(for: routine).count == 1 && app.toggleRequests == [false])
    model.markStepCompleted("s1")
    check("finished celebration hides the confirmed step", model.pendingSteps(for: routine).isEmpty)
    for _ in 0..<10 { await Task.yield() }
    check("finished celebration refreshes the shared dashboard", app.refreshes == 2)

    app.nextDashboard = nil
    _ = await model.toggleStep("s1")
    app.dashboard = nil
    model.markStepCompleted("s1")
    check("logout clears completions and any delayed celebration", model.completedStepIds.isEmpty)
    app.dashboard = snapshot(completed: false, date: today)
    app.duringToggle = { app.auth.sessionVersion += 1; app.dashboard = nil }
    let stale = await model.toggleStep("s1")
    check("a response from a former session cannot finish a check-off", !stale && model.completedStepIds.isEmpty)

    let other = AppState()
    model.bind(to: other)
    app.dashboard = snapshot(completed: true, date: today)
    check("rebinding stops observing the old app state", model.completedStepIds.isEmpty)
    other.dashboard = snapshot(completed: true, date: today)
    check("the replacement app state is observed", model.completedStepIds == ["s1"])

    weak var released: RoutinesViewModel?
    do {
        let temporary = RoutinesViewModel()
        temporary.bind(to: other)
        released = temporary
    }
    check("dashboard observation does not retain the view model", released == nil)

    let editorApp = AppState()
    let editorModel = RoutinesViewModel()
    editorModel.bind(to: editorApp)
    let input = RoutineInput(name: "Morning", period: .morning, days: "0,1,2,3,4,5,6", steps: ["Brush teeth"])
    _ = await editorModel.createRoutine(input)
    _ = await editorModel.updateRoutine(id: "r1", input: input)
    _ = await editorModel.deleteRoutine(id: "r1")
    check("each routine edit refreshes the dashboard only once", editorApp.refreshes == 3)
    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
