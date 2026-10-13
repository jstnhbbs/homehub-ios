import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

let baseline = HubModules.defaults
let phone = baseline.updatingDashboardCardSize(.snacks, size: .large, for: .phone)
let patch = HubModulesPatch(from: baseline, to: phone)
let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as! [String: Any]
check("only the edited device and card are encoded", json.keys.sorted() == ["dashboardCardSizesPhone"]
      && (json["dashboardCardSizesPhone"] as? [String: String]) == ["snacks": "large"])
check("no change sends no fields", HubModulesPatch(from: baseline, to: baseline).isEmpty)

let tablet = baseline.updatingDashboardCardSize(.notes, size: .large, for: .tablet)
let merged = patch.applying(to: tablet)
check("a stale phone does not replace a newer tablet setting", merged.dashboardCardSizesTablet[.notes] == .large)
check("the phone edit is retained", merged.dashboardCardSizesPhone[.snacks] == .large)

let hidden = phone.updatingDashboardCard(.chores, enabled: false)
let combined = patch.merging(HubModulesPatch(from: phone, to: hidden))
check("coalescing carries the skipped earlier edit", combined.applying(to: tablet).dashboardCardSizesPhone[.snacks] == .large)
check("and carries the newer edit", combined.applying(to: tablet).dashboardCards[.chores] == false)
let undone = hidden.updatingDashboardCardSize(.snacks, size: .small, for: .phone)
check("the last edit wins even when it restores a default", combined.merging(HubModulesPatch(from: hidden, to: undone))
      .applying(to: tablet).dashboardCardSizesPhone[.snacks] == .small)

let disabled = baseline.updating(.calendar, enabled: false)
let toggle = HubModulesPatch(from: baseline, to: disabled)
let toggleJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(toggle)) as! [String: Bool]
check("false switches are encoded, not omitted", toggleJSON == ["calendar": false])
check("a remote switch survives an unrelated local edit", patch.applying(to: disabled).calendar == false)

var reordered = baseline
reordered.dashboardOrderPhone.reverse()
let orderPatch = HubModulesPatch(from: baseline, to: reordered)
check("an order changes only its own device", orderPatch.applying(to: tablet).dashboardOrderPhone == reordered.dashboardOrderPhone
      && orderPatch.applying(to: tablet).dashboardOrderTablet == tablet.dashboardOrderTablet)

if failures > 0 { exit(1) }
print("all passed")
