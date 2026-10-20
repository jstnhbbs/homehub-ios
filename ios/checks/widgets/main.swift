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
let registeredKinds = Set(HouseholdWidgetKind.allCases.map { "Tugboat.\($0.rawValue)" }
    + LockWidgetKind.allCases.map { "Tugboat.lock.\($0.rawValue)" } + ["Tugboat.lock.routine"])
check("every reloaded kind is a real widget kind", Set(WidgetActionPolicy.affectedKinds(action: "step") + WidgetActionPolicy.affectedKinds(action: "chore") + WidgetActionPolicy.affectedKinds(action: "endSleep")).isSubset(of: registeredKinds))

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

// Taps waiting for a connection
let queueDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("tugboat-queue-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: queueDirectory) }
let queue = WidgetPendingQueue(directory: queueDirectory)
snapshot.actionError = nil
snapshot.sleeps = [.init(id: "sleep", personId: "child1", start: now.addingTimeInterval(-3600), kind: "nap")]
let tapTime = now.addingTimeInterval(-600)
func pendingTap(_ action: String, _ id: String, at time: Date = tapTime) -> WidgetPendingAction? { WidgetPendingAction.make(action: action, itemId: id, in: snapshot, now: time) }
check("an empty queue has nothing waiting", queue.load().isEmpty && queue.count(userId: "user", now: now) == 0)
let waitingSleep = pendingTap("endSleep", "sleep")!
let waitingStep = pendingTap("step", "s1")!
check("a tap is saved to the queue", queue.enqueue(waitingSleep) && queue.load() == [waitingSleep])
check("the same item twice waits only once", !queue.enqueue(pendingTap("endSleep", "sleep")!) && queue.load().count == 1)
check("another item waits too", queue.enqueue(waitingStep) && queue.count(userId: "user", now: now) == 2)
check("another account's waiting taps aren't counted", queue.count(userId: "other", now: now) == 0)
check("no pending tap is made for an unknown item", pendingTap("step", "missing") == nil && pendingTap("refresh", "") == nil)
check("a chore keeps its period for later", pendingTap("chore", "c1")?.periodKey == snapshot.chores.first { $0.id == "c1" }?.periodKey)
let first = queue.claim(userId: "user", now: now)
check("a sender claims everything waiting, oldest first", first.count == 2 && first[0].tappedAt <= first[1].tappedAt)
check("a second sender at the same time gets nothing", queue.claim(userId: "user", now: now.addingTimeInterval(5)).isEmpty)
check("a claim that was never finished can be taken again", queue.claim(userId: "user", now: now.addingTimeInterval(61)).count == 2)
queue.release(id: waitingSleep.id)
check("a released tap can be taken again at once", queue.claim(userId: "user", now: now.addingTimeInterval(62)).map(\.id) == [waitingSleep.id])
queue.remove(id: waitingSleep.id)
check("a sent tap leaves the queue", queue.load().map(\.id) == [waitingStep.id])
check("a tap more than a day old is dropped, not sent", queue.claim(userId: "user", now: now.addingTimeInterval(24 * 3600 + 700)).isEmpty && queue.load().isEmpty)
queue.enqueue(waitingStep); queue.enqueue(waitingSleep)
let overlaid = queue.overlay(on: snapshot, now: now)
check("waiting taps stay shown when the snapshot is rebuilt from the server", overlaid.steps.first { $0.id == "s1" }?.completed == true && overlaid.sleeps.first { $0.id == "sleep" }?.end == tapTime)
check("the overlay leaves another account's snapshot alone", { var other = snapshot; other.userId = "other"; return queue.overlay(on: other, now: now) == other }())
queue.clear()
check("sign-out clears everything waiting", queue.load().isEmpty)
check("a queue with no App Group does nothing", WidgetPendingQueue(directory: nil).load().isEmpty && !WidgetPendingQueue(directory: nil).enqueue(waitingStep) && WidgetPendingQueue(directory: nil).claim(userId: "user").isEmpty)

// What is sent when a waiting tap goes out
func bodyText(_ request: WidgetWriteRequest?) -> String? {
    guard let request else { return nil }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(AnyEncodable(request.body))).flatMap { String(data: $0, encoding: .utf8) }
}
let soon = waitingSleep.tappedAt.addingTimeInterval(5)
let late = waitingSleep.tappedAt.addingTimeInterval(400)
check("End Sleep sent right away leaves the time to the server", bodyText(waitingSleep.writeRequest(now: soon)) == "{\"action\":\"end\",\"napId\":\"sleep\"}")
check("End Sleep sent late says when it was tapped", bodyText(waitingSleep.writeRequest(now: late))?.contains("\"endedAt\":\"\(WidgetPendingAction.iso(tapTime))\"") == true)
check("the tap time is an ISO 8601 UTC time with fractions", WidgetPendingAction.iso(Date(timeIntervalSince1970: 1_792_000_000.25)).hasSuffix("Z") && WidgetPendingAction.iso(Date(timeIntervalSince1970: 1_792_000_000.25)).contains(".250"))
check("a routine step sent late still says only that it is done", bodyText(waitingStep.writeRequest(now: late)) == "{\"completed\":true,\"localDate\":\"\(snapshot.localDate)\",\"stepId\":\"s1\"}")
check("a queued chore is rebuilt without the snapshot", pendingTap("chore", "c1")?.writeRequest()?.path == "/api/mobile/v1/chores/toggle")

// Putting a refused tap back, and telling offline from refused
check("undoing a step marks it not done", WidgetActionPolicy.undoing(action: "step", itemId: "s1", in: WidgetActionPolicy.applying(action: "step", itemId: "s1", to: snapshot, at: now)).steps.first { $0.id == "s1" }?.completed == false)
check("undoing End Sleep makes it run again", WidgetActionPolicy.undoing(action: "endSleep", itemId: "sleep", in: WidgetActionPolicy.applying(action: "endSleep", itemId: "sleep", to: snapshot, at: now)).sleeps.first?.end == nil)
check("applying an action twice changes nothing more", WidgetActionPolicy.applying(action: "endSleep", itemId: "sleep", to: WidgetActionPolicy.applying(action: "endSleep", itemId: "sleep", to: snapshot, at: now), at: now.addingTimeInterval(60)).sleeps.first?.end == now)
check("no connection counts as offline", [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed].allSatisfy { WidgetNetworkFailure.isOffline(URLError($0)) })
check("a cancelled or bad request doesn't count as offline", !WidgetNetworkFailure.isOffline(URLError(.cancelled)) && !WidgetNetworkFailure.isOffline(URLError(.badURL)) && !WidgetNetworkFailure.isOffline(CocoaError(.fileNoSuchFile)))
// Lock Screen: daily state expires, persistent lists and selected children do not silently switch.
check("groceries survives household midnight", !LockWidgetKind.groceries.requiresCurrentDay)
check("celebration countdown survives household midnight", !LockWidgetKind.celebrations.requiresCurrentDay)
check("sleep survives household midnight", !LockWidgetKind.sleep.requiresCurrentDay)
check("coming up, dinner and chores require today's snapshot", [LockWidgetKind.today, .evening, .chores].allSatisfy(\.requiresCurrentDay))
check("existing Today and Evening identifiers are preserved", LockWidgetKind.today.rawValue == "today" && LockWidgetKind.evening.rawValue == "evening")
check("seven Lock Screen widgets are registered by kind", LockWidgetKind.allCases.count + 1 == 7)
check("Lock Screen routines reload after a check-off", WidgetActionPolicy.affectedKinds(action: "step").contains("Tugboat.lock.routine"))
check("Coming Up reloads after a routine check-off", WidgetActionPolicy.affectedKinds(action: "step").contains("Tugboat.lock.today"))
check("Lock Screen chores and Coming Up reload after a chore check-off", Set(WidgetActionPolicy.affectedKinds(action: "chore")).isSuperset(of: ["Tugboat.lock.chores", "Tugboat.lock.today"]))
check("Lock Screen sleep reloads after End Sleep", WidgetActionPolicy.affectedKinds(action: "endSleep").contains("Tugboat.lock.sleep"))
check("Coming Up preserves overdue wording", LockWidgetContent.status(for: .init(id: "late", title: "Plants", detail: "Overdue", start: now, destination: "chores")) == "Overdue")
check("Coming Up preserves in-progress wording", LockWidgetContent.status(for: .init(id: "now", title: "Pickup", detail: "Now", start: now, destination: "calendar")) == "Now")
check("future items use Coming Up", LockWidgetContent.status(for: .init(id: "future", title: "Pickup", detail: "Calendar", start: tomorrow, destination: "calendar")) == "Coming Up")
check("a missing child asks for reselection", !LockWidgetContent.validChild("missing", in: snapshot))
check("everyone and an existing child are valid selections", LockWidgetContent.validChild(nil, in: snapshot) && LockWidgetContent.validChild("child1", in: snapshot))
var lockSnapshot = snapshot
lockSnapshot.people.append(.init(id: "parent", name: "Parent", color: "#5F8153", isChild: false))
check("an adult cannot be the selected child", !LockWidgetContent.validChild("parent", in: lockSnapshot))
lockSnapshot.sleeps = [
    .init(id: "alex-sleep", personId: "child1", start: now.addingTimeInterval(-3600), kind: "night"),
    .init(id: "sam-ended", personId: "child2", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-1200), kind: "nap")
]
check("selected sleeping child has only their timer", LockWidgetContent.sleeping(in: lockSnapshot, childId: "child1").map(\.personId) == ["child1"])
check("selected awake child never displays a sibling's sleep", LockWidgetContent.sleeping(in: lockSnapshot, childId: "child2").isEmpty)
check("selected awake child's timer uses their last sleep", LockWidgetContent.awake(in: lockSnapshot, childId: "child2", at: now).first?.since == now.addingTimeInterval(-1200))
check("sleeping child is not shown as awake", LockWidgetContent.awake(in: lockSnapshot, childId: "child1", at: now).isEmpty)
lockSnapshot.events = []
lockSnapshot.chores = [.init(id: "late", title: "Plants", periodKey: "once", dueAt: now.addingTimeInterval(-60), completed: false)]
check("Coming Up opens the displayed chore's page", WidgetRoute.destination(from: LockWidgetKind.today.url(in: lockSnapshot, at: now)) == "chores")
lockSnapshot.dinner?.recipeId = recipeId
check("Dinner opens its saved recipe", WidgetRoute.recipeId(from: LockWidgetKind.evening.url(in: lockSnapshot, at: now)) == recipeId)
check("old Dinner never links to yesterday's recipe", WidgetRoute.recipeId(from: LockWidgetKind.evening.url(in: lockSnapshot, at: tomorrow)) == nil)
check("Celebrations opens Celebrations, not Food", WidgetRoute.destination(from: LockWidgetKind.celebrations.url(in: lockSnapshot, at: now)) == "birthdays")
lockSnapshot.celebrations = [.init(id: "yesterday", name: "Old", date: "2026-10-12", years: 5, isAnniversary: false),
    .init(id: "next", name: "Alex", date: "2026-10-14", years: 5, isAnniversary: false)]
check("celebration days use the household timezone", LockWidgetContent.nextCelebration(in: lockSnapshot, at: now)?.days == 1)
check("celebration countdown advances at midnight", LockWidgetContent.nextCelebration(in: lockSnapshot, at: tomorrow)?.days == 0)
lockSnapshot.enabledDestinations = []
check("hidden sections are not presented as empty or completed", !LockWidgetKind.groceries.isEnabled(in: lockSnapshot) && !LockWidgetKind.sleep.isEnabled(in: lockSnapshot))
if failures > 0 { exit(1) }
print("all passed")
