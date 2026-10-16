import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
let now = ISO8601DateFormatter().date(from: "2026-10-14T04:30:00Z")!
var snapshot = WidgetSnapshot(userId: "user", householdId: "home", householdName: "Family",
    timezone: "America/Chicago", localDate: "2026-10-13", updatedAt: now,
    accentLight: "#57764C", accentDark: "#5F8153", enabledDestinations: Array(WidgetRoute.destinations),
    people: [.init(id: "child1", name: "Alex", color: "#5F8153", isChild: true), .init(id: "child2", name: "Sam", color: "#56A2DC", isChild: true)],
    steps: [.init(id: "s1", label: "Brush teeth", personId: "child1", period: "morning", completed: false),
            .init(id: "s2", label: "Read", personId: "child2", period: "evening", completed: true),
            .init(id: "shared", label: "Tidy up", period: "evening", completed: false)],
    chores: [.init(id: "c1", title: "Plants", periodKey: "once", dueAt: now.addingTimeInterval(600), completed: false)],
    events: [.init(id: "past", title: "Past", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), allDay: false),
             .init(id: "active", title: "Now", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(600), allDay: false),
             .init(id: "allDay", title: "All day", start: now, end: now.addingTimeInterval(3600), allDay: true)],
    dinner: .init(title: "Pasta"), sleeps: [], notes: [.init(id: "n1", title: "Newest", body: "", pinned: false), .init(id: "n2", title: "Pinned", body: "Reminder", pinned: true)],
    groceries: ["Milk"], groceryCount: 1, celebrations: [])
check("household timezone determines the day", snapshot.isCurrentDay(at: now))
let tomorrow = now.addingTimeInterval(3600)
check("cached checklist expires at household midnight", !snapshot.isCurrentDay(at: tomorrow))
check("stale Up Next never shows yesterday's tasks", snapshot.upcoming(at: tomorrow).isEmpty)
check("past and all-day events do not occupy Up Next", snapshot.upcoming(at: now).map(\.id) == ["event:active", "chore:c1"])
check("child selection includes only that child and shared routines", snapshot.routineSteps(personId: "child1").map(\.id) == ["s1", "shared"])
check("bedtime steps come first at night in the household timezone", snapshot.routineSteps(personId: "child1", at: now).first?.id == "shared")
check("default note chooses pinned before newest", snapshot.selectedNote(id: nil)?.id == "n2")
check("explicit note selection is respected", snapshot.selectedNote(id: "n1")?.id == "n1")
check("deleted selected note doesn't silently become another note", snapshot.selectedNote(id: "missing") == nil)
for destination in WidgetRoute.destinations {
    check("\(destination) deep link round trips", WidgetRoute.destination(from: WidgetRoute.url(destination: destination)) == destination)
}
for value in ["https://widget/chores", "tugboat://other/chores", "tugboat://widget/settings", "tugboat://widget/chores?delete=1"] {
    check("unexpected deep links are rejected", WidgetRoute.destination(from: URL(string: value)!) == nil)
}
let recipeId = "12345678-1234-4234-8234-123456789012"
let dinnerURL = WidgetRoute.url(destination: "meals", recipeId: recipeId)
check("dinner deep link carries only a valid recipe ID", WidgetRoute.destination(from: dinnerURL) == "meals" && WidgetRoute.recipeId(from: dinnerURL) == recipeId)
check("malformed recipe query is rejected", WidgetRoute.destination(from: URL(string: "tugboat://widget/meals?recipe=invalid")!) == nil)
check("extra recipe query parameters are rejected", WidgetRoute.destination(from: URL(string: "tugboat://widget/meals?recipe=\(recipeId)&delete=1")!) == nil)
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("tugboat-widgets-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: directory) }
let store = WidgetStore(directory: directory)
check("empty cache shows signed-out state", store.load() == nil)
check("first snapshot saves", store.save(snapshot))
check("stored snapshot round trips", store.load() == snapshot)
snapshot.updatedAt = now.addingTimeInterval(60)
check("equal refresh doesn't churn file or widget timelines", !store.save(snapshot))
check("explicit refresh updates the freshness timestamp", store.save(snapshot, force: true) && store.load()?.updatedAt == snapshot.updatedAt)
snapshot.updatedAt = now.addingTimeInterval(961)
check("freshness timestamp advances at fifteen minutes", store.save(snapshot))
snapshot.steps[0].completed = true
check("completion is persisted immediately", store.save(snapshot) && store.load()?.steps[0].completed == true)
snapshot.actionError = "Offline"
check("failed action feedback persists without losing data", store.save(snapshot) && store.load()?.notes.count == 2)
store.clear()
check("sign-out removes household information", store.load() == nil)
check("missing App Group has no private-storage fallback", WidgetStore(directory: nil).load() == nil)
check("all nine widget types exist", HouseholdWidgetKind.allCases.count == 9)
func allowed(_ action: String, _ id: String, user: String = "user", home: String = "home", day: String = "2026-10-13") -> Bool {
    WidgetActionPolicy.allows(action: action, itemId: id, userId: user, householdId: home, localDate: day, current: snapshot, now: now)
}
check("current routine can be completed", allowed("step", "s1"))
check("unknown routine cannot be completed", !allowed("step", "missing"))
check("old day's routine cannot be completed", !allowed("step", "s1", day: "2026-10-12"))
check("old day's chore cannot be completed", !allowed("chore", "c1", day: "2026-10-12"))
check("crossing midnight during a request also blocks yesterday's tasks", !WidgetActionPolicy.allows(action: "step", itemId: "s1", userId: "user", householdId: "home", localDate: snapshot.localDate, current: snapshot, now: tomorrow))
check("another account's widget cannot write", !allowed("step", "s1", user: "other"))
check("another household's widget cannot write", !allowed("step", "s1", home: "other"))
check("unknown actions are refused", !allowed("delete", "s1"))
snapshot.sleeps = [.init(id: "sleep", personId: "child1", start: now.addingTimeInterval(-3600), kind: "night")]
check("sleep can end across midnight", allowed("endSleep", "sleep", day: "2026-10-12"))
snapshot.sleeps[0].end = now
check("ended sleep cannot be ended again", !allowed("endSleep", "sleep"))
check("refresh is allowed for an old day", allowed("refresh", "", day: "2026-10-12"))
check("a follow-up read across midnight doesn't check off tomorrow's routine", !WidgetActionPolicy.appliesCompletion(action: "step", writtenDay: "2026-10-13", currentDay: "2026-10-14"))
check("a follow-up read across midnight doesn't check off tomorrow's daily chore", !WidgetActionPolicy.appliesCompletion(action: "chore", writtenDay: "2026-10-13", currentDay: "2026-10-14", writtenPeriod: "2026-10-13", currentPeriod: "2026-10-14"))
check("a confirmed weekly completion still applies within the same week", WidgetActionPolicy.appliesCompletion(action: "chore", writtenDay: "2026-10-13", currentDay: "2026-10-14", writtenPeriod: "2026-W42", currentPeriod: "2026-W42"))
snapshot.sleeps = [.init(id: "overnight", personId: "child1", start: tomorrow.addingTimeInterval(-3600), end: tomorrow, kind: "night")]
check("overnight sleep totals include only the current day's portion", snapshot.sleepMinutes(on: tomorrow) == 30)

// Showing a tap before the network round trip, and putting it back if the write fails
snapshot.sleeps = [.init(id: "sleep", personId: "child1", start: now.addingTimeInterval(-3600), kind: "night")]
func early(_ action: String, _ id: String, day: String = "2026-10-13", from base: WidgetSnapshot? = nil) -> WidgetSnapshot? {
    WidgetActionPolicy.appliedEarly(action: action, itemId: id, userId: "user", householdId: "home", localDate: day, to: base ?? snapshot, now: now)
}
snapshot.actionError = nil
let baseline = snapshot
check("a routine tap shows as done at once", early("step", "s1")?.steps.first { $0.id == "s1" }?.completed == true)
check("a routine tap changes only that step", early("step", "s1")?.steps.filter(\.completed).count == baseline.steps.filter(\.completed).count + (baseline.steps.first { $0.id == "s1" }?.completed == true ? 0 : 1))
check("a chore tap shows as done at once", early("chore", "c1")?.chores.first { $0.id == "c1" }?.completed == true)
check("ending a sleep shows it ended at once", early("endSleep", "sleep")?.sleeps.first { $0.id == "sleep" }?.end == now)
check("an early update clears an old error", { var base = baseline; base.actionError = "Offline"; return early("step", "s1", from: base)?.actionError == nil }())
check("nothing is shown early for an unknown item", early("step", "missing") == nil && early("chore", "missing") == nil && early("endSleep", "missing") == nil)
check("nothing is shown early for yesterday's widget", early("step", "s1", day: "2026-10-12") == nil)
check("nothing is shown early for another account", WidgetActionPolicy.appliedEarly(action: "step", itemId: "s1", userId: "other", householdId: "home", localDate: "2026-10-13", to: baseline, now: now) == nil)
check("refresh and unknown actions change nothing early", early("refresh", "") == nil && early("delete", "s1") == nil)
check("an already ended sleep isn't ended again early", { var base = baseline; base.sleeps[0].end = now.addingTimeInterval(-60); return early("endSleep", "sleep", from: base) == nil }())
if let shown = early("step", "s1") {
    check("a failed write puts the step back", WidgetActionPolicy.reverted(action: "step", itemId: "s1", in: shown, from: baseline) == baseline)
    var newer = shown
    newer.notes.append(.init(id: "n3", title: "New", body: "", pinned: false))
    let rolledBack = WidgetActionPolicy.reverted(action: "step", itemId: "s1", in: newer, from: baseline)
    check("putting it back keeps anything newer the app saved", rolledBack.notes.count == baseline.notes.count + 1 && rolledBack.steps == baseline.steps)
} else { check("the routine tap is available to revert", false) }
if let shown = early("chore", "c1") { check("a failed write puts the chore back", WidgetActionPolicy.reverted(action: "chore", itemId: "c1", in: shown, from: baseline) == baseline) }
if let shown = early("endSleep", "sleep") { check("a failed write puts the sleep back", WidgetActionPolicy.reverted(action: "endSleep", itemId: "sleep", in: shown, from: baseline) == baseline) }

check("a sleep tap reloads the Sleep widget first", WidgetActionPolicy.affectedKinds(action: "endSleep").first == "Tugboat.sleep")
check("a routine tap reloads the Routines widget first", WidgetActionPolicy.affectedKinds(action: "step").first == "Tugboat.routines")
check("a chore tap reloads the Chores widget first", WidgetActionPolicy.affectedKinds(action: "chore").first == "Tugboat.chores")
check("only widgets that show the change are reloaded", !WidgetActionPolicy.affectedKinds(action: "endSleep").contains("Tugboat.groceries") && WidgetActionPolicy.affectedKinds(action: "refresh").isEmpty)
check("every reloaded kind is a real widget kind", Set(WidgetActionPolicy.affectedKinds(action: "step") + WidgetActionPolicy.affectedKinds(action: "chore") + WidgetActionPolicy.affectedKinds(action: "endSleep")).allSatisfy { kind in HouseholdWidgetKind.allCases.contains { "Tugboat.\($0.rawValue)" == kind } })

// What a tap sends, and where it may send it
func body(_ request: WidgetWriteRequest?) -> String? {
    guard let request else { return nil }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(AnyEncodable(request.body))).flatMap { String(data: $0, encoding: .utf8) }
}
struct AnyEncodable: Encodable { let value: any Encodable; init(_ value: any Encodable) { self.value = value }; func encode(to encoder: Encoder) throws { try value.encode(to: encoder) } }
snapshot.sleeps = [.init(id: "sleep", personId: "child1", start: now.addingTimeInterval(-3600), kind: "night")]
let routineWrite = WidgetActionPolicy.writeRequest(action: "step", itemId: "s1", in: snapshot)
check("a routine tap goes to the toggle-step route", routineWrite?.path == "/api/mobile/v1/routines/toggle-step")
check("a routine tap says the state wanted", body(routineWrite) == "{\"completed\":true,\"localDate\":\"\(snapshot.localDate)\",\"stepId\":\"s1\"}")
let choreWrite = WidgetActionPolicy.writeRequest(action: "chore", itemId: "c1", in: snapshot)
check("a chore tap goes to the toggle route with its period", choreWrite?.path == "/api/mobile/v1/chores/toggle" && body(choreWrite)?.contains("\"periodKey\":\"\(snapshot.chores.first { $0.id == "c1" }!.periodKey)\"") == true && body(choreWrite)?.contains("\"completed\":true") == true)
let sleepWrite = WidgetActionPolicy.writeRequest(action: "endSleep", itemId: "sleep", in: snapshot)
check("ending a sleep posts the end action for that sleep", sleepWrite?.path == "/api/mobile/v1/naps" && body(sleepWrite) == "{\"action\":\"end\",\"napId\":\"sleep\"}")
check("no request for an item that isn't in the snapshot", WidgetActionPolicy.writeRequest(action: "step", itemId: "missing", in: snapshot) == nil && WidgetActionPolicy.writeRequest(action: "chore", itemId: "missing", in: snapshot) == nil && WidgetActionPolicy.writeRequest(action: "endSleep", itemId: "missing", in: snapshot) == nil)
check("no request for refresh or unknown actions", WidgetActionPolicy.writeRequest(action: "refresh", itemId: "", in: snapshot) == nil && WidgetActionPolicy.writeRequest(action: "delete", itemId: "s1", in: snapshot) == nil)
func server(_ value: String?) -> URL? { var copy = snapshot; copy.server = value; return copy.serverURL }
check("a snapshot saved before servers were recorded can't send", server(nil) == nil)
check("https servers are allowed", server("https://example.com") != nil)
check("plain http is allowed only for a local server", server("http://localhost:3000") != nil && server("http://192.168.1.2:3000") == nil && server("http://example.com") == nil)
check("other schemes and malformed values are refused", server("ftp://example.com") == nil && server("not a url") == nil && server("") == nil)
if failures > 0 { exit(1) }
print("all passed")
