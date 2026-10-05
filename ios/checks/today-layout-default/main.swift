import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}
func names(_ cards: [DashboardCardId]) -> String { cards.filter { $0 != .weather }.map(\.rawValue).joined(separator: ",") }

let target = DashboardLayoutTarget.phone

// A family's own arrangement: Notes first and big, Sleep next, Groceries and Birthdays off, Snacks large.
var good = HubModules.defaults
good.dashboardOrderPhone = [.weather, .notes, .sleep, .routines, .chores, .meals, .snacks, .schedule, .groceries, .birthdays]
good = good.updatingDashboardCardSize(.snacks, size: .expanded, for: .phone)
good = good.updatingDashboardCardSize(.schedule, size: .standard, for: .phone)
good = good.updatingDashboardCard(.groceries, enabled: false)
good = good.updatingDashboardCard(.birthdays, enabled: false)
let saved = TodayLayoutDefault.capture(from: good, target: target)

// Then it gets messy.
var messy = good
messy.dashboardOrderPhone = messy.dashboardOrderPhone.reversed()
messy = messy.updatingDashboardCardSize(.notes, size: .standard, for: .phone)
messy = messy.updatingDashboardCardSize(.routines, size: .expanded, for: .phone)
messy = messy.updatingDashboardCard(.groceries, enabled: true)
messy = messy.updatingDashboardCard(.sleep, enabled: false)

let restored = saved.applied(to: messy, target: target)
check("the order comes back", names(restored.dashboardOrderPhone), names(good.dashboardOrderPhone))
check("sizes come back", good.dashboardCardSizesPhone == restored.dashboardCardSizesPhone ? "same" : "different", "same")
check("which cards are on comes back", good.dashboardCards == restored.dashboardCards ? "same" : "different", "same")
check("the whole layout is exactly as saved", restored == good ? "same" : "different", "same")

// Only the Today cards are touched.
var elsewhere = messy
elsewhere.sidebarOrder = elsewhere.sidebarOrder.reversed()
elsewhere.snacks = false
elsewhere.dashboardOrderTablet = [.notes, .schedule]
elsewhere = elsewhere.updatingDashboardCardSize(.chores, size: .expanded, for: .tablet)
let kept = saved.applied(to: elsewhere, target: target)
check("navigation order is left alone", kept.sidebarOrder == elsewhere.sidebarOrder ? "same" : "different", "same")
check("Food tabs are left alone", String(kept.snacks), "false")
check("the other kind of device's order is left alone", names(kept.dashboardOrderTablet), names(elsewhere.dashboardOrderTablet))
check("and its sizes", kept.dashboardCardSizesTablet == elsewhere.dashboardCardSizesTablet ? "same" : "different", "same")

// The tablet gets its own saved layout.
var tabletGood = HubModules.defaults
tabletGood.dashboardOrderTablet = [.weather, .sleep, .notes, .schedule, .routines, .chores, .meals, .snacks, .groceries, .birthdays]
let tabletSaved = TodayLayoutDefault.capture(from: tabletGood, target: .tablet)
let tabletRestored = tabletSaved.applied(to: HubModules.defaults, target: .tablet)
check("tablet order restored", names(tabletRestored.dashboardOrderTablet), names(tabletGood.dashboardOrderTablet))
check("without touching the phone's", names(tabletRestored.dashboardOrderPhone), names(HubModules.defaults.dashboardOrderPhone))

// Already the same: nothing to restore.
check("matches when nothing has changed", String(saved.matches(good, target: target)), "true")
check("does not match once it is messy", String(saved.matches(messy, target: target)), "false")
check("after restoring it matches again", String(saved.matches(restored, target: target)), "true")

// A card added to the app after the layout was saved is kept, not lost.
var older = saved
older.order.removeAll { $0 == DashboardCardId.birthdays.rawValue }
older.sizes.removeValue(forKey: DashboardCardId.birthdays.rawValue)
older.enabled.removeValue(forKey: DashboardCardId.birthdays.rawValue)
let withNewCard = older.applied(to: messy, target: target)
check("a card the saved layout never knew is kept", String(withNewCard.dashboardOrderPhone.contains(.birthdays)), "true")
check("at the end", names(Array(withNewCard.dashboardOrderPhone.suffix(1))), "birthdays")
check("no card is repeated", String(Set(withNewCard.dashboardOrderPhone).count == withNewCard.dashboardOrderPhone.count), "true")
check("every card is still there", String(Set(withNewCard.dashboardOrderPhone) == Set(DashboardCardId.allCases)), "true")

// A card that no longer exists is ignored, and so is a size nobody knows.
var stale = saved
stale.order.insert("hologram", at: 0)
stale.sizes["hologram"] = "expanded"
stale.sizes[DashboardCardId.chores.rawValue] = "gigantic"
stale.enabled["hologram"] = true
let tolerant = stale.applied(to: messy, target: target)
check("an unknown card is dropped", String(tolerant.dashboardOrderPhone.count), String(DashboardCardId.allCases.count))
check("an unknown size keeps the current one", String(tolerant.dashboardCardSizesPhone[.chores] == messy.dashboardCardSizesPhone[.chores]), "true")

// Saving and loading.
let suite = UserDefaults(suiteName: "today-layout-check-\(UUID().uuidString)")!
let store = TodayLayoutDefaultStore(defaults: suite)
check("nothing saved yet", String(store.load(userId: "u1", target: .phone) == nil), "true")
store.save(saved, userId: "u1", target: .phone)
check("saved layout loads back identical", String(store.load(userId: "u1", target: .phone) == saved), "true")
check("it is kept per kind of device", String(store.load(userId: "u1", target: .tablet) == nil), "true")
check("and per person", String(store.load(userId: "u2", target: .phone) == nil), "true")
store.save(tabletSaved, userId: "u1", target: .tablet)
check("the phone's is not replaced by the tablet's", String(store.load(userId: "u1", target: .phone) == saved), "true")
store.clear(userId: "u1", target: .phone)
check("clearing removes only that one", "\(store.load(userId: "u1", target: .phone) == nil) \(store.load(userId: "u1", target: .tablet) != nil)", "true true")

// The saved copy survives being written out and read back as plain JSON.
let json = String(data: try JSONEncoder().encode(saved), encoding: .utf8) ?? ""
check("it is readable JSON with plain keys", String(json.contains("\"notes\"") && json.contains("\"order\"")), "true")

if failures > 0 {
    print("\(failures) failed")
    exit(1)
}
print("all passed")
