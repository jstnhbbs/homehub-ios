import Foundation

var failures = 0
func check(_ label: String, _ ok: Bool) {
    if ok { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

// Progress
var state = HouseholdSetupState()
check("a new state has nothing done", state.doneCount == 0 && state.totalCount == 4)
check("progress reads 0 of 4", state.progressText == "0 of 4 done")
check("the card shows and setup opens by itself", state.showsCard && state.shouldPresentAutomatically)
check("the first step is family", state.nextStep == .family)
state.complete(.family)
state.complete(.family)
check("completing twice counts once", state.doneCount == 1 && state.progressText == "1 of 4 done")
check("the next step skips what is done", state.nextStep == .routines)
state.presented = true
check("once shown it doesn't open again by itself", !state.shouldPresentAutomatically && state.showsCard)
HouseholdSetupStep.allCases.forEach { state.complete($0) }
check("all done finishes it", state.isFinished && state.nextStep == nil)
check("a finished setup hides the card", !state.showsCard)
var dismissed = HouseholdSetupState()
dismissed.dismissed = true
check("dismissing hides the card and the automatic opening", !dismissed.showsCard && !dismissed.shouldPresentAutomatically)

// Storage
let suite = UserDefaults(suiteName: "household-setup-check-\(UUID().uuidString)")!
let store = HouseholdSetupStore(defaults: suite)
check("a household nobody began has no state", store.load(householdId: "h1") == nil)
store.begin(householdId: "h1")
check("beginning stores an empty state", store.load(householdId: "h1") == HouseholdSetupState())
var saved = store.load(householdId: "h1")!
saved.complete(.chores)
saved.presented = true
store.save(saved, householdId: "h1")
store.begin(householdId: "h1")
check("beginning again keeps progress", store.load(householdId: "h1")?.isDone(.chores) == true)
check("households are separate", store.load(householdId: "h2") == nil)
check("the key is namespaced", HouseholdSetupStore.key(for: "h1") == "tugboat.setup.h1")

// Words
let steps = HouseholdSetupStep.allCases
check("every step has a title, a sentence and an icon", steps.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.systemImage.isEmpty })
check("sentences end with a full stop and titles don't", steps.allSatisfy { $0.detail.hasSuffix(".") && !$0.title.hasSuffix(".") })

// Starters
check("three routine starters, each with steps", HouseholdSetupStarters.routines.count == 3 && HouseholdSetupStarters.routines.allSatisfy { $0.steps.count >= 3 })
check("routine periods are ones the server knows", HouseholdSetupStarters.routines.allSatisfy { ["morning", "afternoon", "evening"].contains($0.period) })
check("every step starts with an emoji", HouseholdSetupStarters.routines.flatMap(\.steps).allSatisfy { ($0.unicodeScalars.first?.properties.isEmoji ?? false) })
check("chore starters are all different", Set(HouseholdSetupStarters.chores.map(\.title)).count == HouseholdSetupStarters.chores.count)
check("a weekly chore names its day", HouseholdSetupStarters.chores.first { !$0.daily }?.repeatText == "Every Tuesday")
check("a daily chore says every day", HouseholdSetupStarters.chores.first { $0.daily }?.repeatText == "Every day")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("all passed")
