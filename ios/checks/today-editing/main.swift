import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}
func names(_ cards: [DashboardCardId]) -> String { cards.map(\.rawValue).joined(separator: ",") }

let order: [DashboardCardId] = [.schedule, .routines, .chores, .meals, .snacks]

// Dragging one card onto another.
check("dragging forward puts it in the target's place", names(TodayLayoutEditing.moving(.schedule, ontoPositionOf: .chores, in: order)), "routines,chores,schedule,meals,snacks")
check("dragging backward does too", names(TodayLayoutEditing.moving(.snacks, ontoPositionOf: .routines, in: order)), "schedule,snacks,routines,chores,meals")
check("onto itself changes nothing", names(TodayLayoutEditing.moving(.chores, ontoPositionOf: .chores, in: order)), names(order))
check("onto a card that is not there changes nothing", names(TodayLayoutEditing.moving(.chores, ontoPositionOf: .sleep, in: order)), names(order))

// The move buttons for VoiceOver.
check("one earlier", names(TodayLayoutEditing.moving(.chores, by: -1, in: order)), "schedule,chores,routines,meals,snacks")
check("one later", names(TodayLayoutEditing.moving(.chores, by: 1, in: order)), "schedule,routines,meals,chores,snacks")
check("not past the start", names(TodayLayoutEditing.moving(.schedule, by: -1, in: order)), names(order))
check("not past the end", names(TodayLayoutEditing.moving(.snacks, by: 1, in: order)), names(order))

// The iPhone pairs half-width cards in order; a full-width card may not split a pair.
func half(_ card: DashboardCardId) -> Bool { [.schedule, .routines, .chores, .meals, .groceries, .notes, .sleep].contains(card) }
func lonely(_ cards: [DashboardCardId]) -> String { String(TodayLayoutEditing.lonelyHalfWidthCount(in: cards, isHalfWidth: half)) }
func allowed(_ card: DashboardCardId, _ from: [DashboardCardId], _ to: [DashboardCardId]) -> String {
    String(TodayLayoutEditing.allowsPhoneMove(of: card, from: from, to: to, isHalfWidth: half))
}
check("two pairs, none alone", lonely([.schedule, .routines, .chores, .meals]), "0")
check("an odd one at the end is alone", lonely([.schedule, .routines, .chores]), "1")
check("a full card leaves the waiting half alone", lonely([.schedule, .snacks, .routines, .chores]), "1")
check("two halves split by a full card are both alone", lonely([.schedule, .snacks, .routines, .birthdays]), "2")
check("full cards alone are fine", lonely([.snacks, .birthdays]), "0")
let paired: [DashboardCardId] = [.schedule, .routines, .snacks, .chores, .meals]
check("a full card may not drop between a pair", allowed(.snacks, paired, [.schedule, .snacks, .routines, .chores, .meals]), "false")
check("it may go before the pair", allowed(.snacks, paired, [.snacks, .schedule, .routines, .chores, .meals]), "true")
check("it may go after the pair", allowed(.snacks, [.snacks, .schedule, .routines, .chores, .meals], [.schedule, .routines, .snacks, .chores, .meals]), "true")
check("it may not split the second pair either", allowed(.snacks, paired, [.schedule, .routines, .chores, .snacks, .meals]), "false")
check("a half card can go between a pair", allowed(.chores, paired, [.schedule, .chores, .routines, .snacks, .meals]), "true")
check("moving a full card never makes it worse than it was", allowed(.snacks, [.schedule, .snacks, .routines], [.schedule, .routines, .snacks]), "true")

// Saving: cards that are off keep their places.
let stored: [DashboardCardId] = [.weather, .schedule, .routines, .chores, .meals, .snacks, .sleep]
// Routines and meals are off, so the visible cards are these four.
let rearranged = TodayLayoutEditing.storedOrder(stored, afterArranging: [.sleep, .chores, .snacks, .schedule])
check("hidden cards stay where they were", names(rearranged), "weather,sleep,routines,chores,meals,snacks,schedule,groceries,notes,birthdays")
check("nothing is lost or repeated", String(Set(rearranged).count), String(rearranged.count))
check("a card missing from the stored order is still kept", names(TodayLayoutEditing.storedOrder([.schedule], afterArranging: [.notes, .schedule])).hasPrefix("notes,schedule") ? "kept" : "lost", "kept")

var modules = HubModules.defaults
modules.dashboardOrderTablet = [.weather, .schedule, .routines, .chores, .meals, .snacks, .sleep, .groceries, .notes, .birthdays]
let arranged = modules.arrangingDashboardCards([.notes, .schedule, .chores], for: .tablet)
check("arranging changes only that device's order", names(arranged.dashboardOrderPhone), names(modules.dashboardOrderPhone))
check("the arranged cards fill their own places, the rest stay", names(arranged.dashboardOrderTablet), "weather,notes,routines,schedule,meals,snacks,sleep,groceries,chores,birthdays")

// Which cards can be added back.
var some = HubModules.defaults
some = some.updatingDashboardCard(.snacks, enabled: false)
some = some.updatingDashboardCard(.sleep, enabled: false)
some = some.updatingDashboardCard(.weather, enabled: false)
check("turned-off cards can be added back, weather never", names(TodayLayoutEditing.addableCards(in: some)), "snacks,sleep")
let noSleepModule = some.updating(.sleep, enabled: false)
check("a card whose module is off can't be added", names(TodayLayoutEditing.addableCards(in: noSleepModule)), "snacks")

// Resizing: every card offers every size.
check("a size the card offers is kept", DashboardCardId.schedule.clamped(.large).rawValue, "large")
check("a card that used to stop at medium offers large too", DashboardCardId.sleep.clamped(.large).rawValue, "large")
check("the menu lists every size", DashboardCardId.sleep.allowedSizes.map(\.rawValue).joined(separator: ","), "small,medium,large")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
