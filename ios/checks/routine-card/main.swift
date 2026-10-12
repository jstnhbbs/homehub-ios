import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func step(_ label: String, _ period: RoutinePeriod, done: Bool = false, profile: String? = "maya") -> RoutineStepRow {
    RoutineStepRow(id: label, label: label, routineName: "R", period: period, profileId: profile, completed: done, completedAt: nil, completedByName: nil)
}
func group(_ id: String, _ steps: [RoutineStepRow]) -> RoutineProgressGroup {
    RoutineProgressGroup(id: id, name: id.capitalized, color: "#d87861", avatar: nil, steps: steps)
}
func labels(_ steps: [RoutineStepRow]) -> String { steps.map(\.label).joined(separator: ",") }

// MARK: parts of the day

check("early morning", RoutineCardSummary.period(hour: 7).rawValue, "morning")
check("noon is the afternoon", RoutineCardSummary.period(hour: 12).rawValue, "afternoon")
check("after school", RoutineCardSummary.period(hour: 16).rawValue, "afternoon")
check("evening", RoutineCardSummary.period(hour: 19).rawValue, "evening")
check("the small hours belong to the evening", RoutineCardSummary.period(hour: 2).rawValue, "evening")

// MARK: order

let steps = [step("dress", .morning), step("snack", .afternoon), step("bath", .evening), step("teeth", .morning, done: true), step("read", .evening)]
let afternoon = RoutineCardSummary(groups: [group("maya", steps)], period: .afternoon)
check("this part of the day first, then on, then back; done last", labels(afternoon.ordered(steps)), "snack,bath,read,dress,teeth")
let morning = RoutineCardSummary(groups: [group("maya", steps)], period: .morning)
check("in the morning, morning first", labels(morning.ordered(steps)), "dress,snack,bath,read,teeth")

// MARK: wording

let two = RoutineCardSummary(groups: [group("maya", [step("bath", .evening), step("read", .evening, done: true)]), group("leo", [step("teeth", .evening)])], period: .evening)
check("headline counts steps", two.headline, "1 of 3")
check("line", two.line, "1 of 3 steps done")
check("the next step names whose it is when there are several", two.caption { $0.label }, "Next: bath · Maya")
let one = RoutineCardSummary(groups: [group("maya", [step("bath", .evening)])], period: .evening)
check("one person needs no name", one.caption { $0.label }, "Next: bath")

let done = RoutineCardSummary(groups: [group("maya", [step("bath", .evening, done: true)])], period: .evening)
check("all done", done.headline, "All done")
check("all done caption", done.caption { $0.label }, "Nice work")
check("all done line", done.line, "All 1 steps done")
let none = RoutineCardSummary(groups: [], period: .morning)
check("no routines", none.headline, "None today")
check("no routines caption", none.caption { $0.label }, "No routines today")

// the next step skips a finished child
let skip = RoutineCardSummary(groups: [group("maya", [step("bath", .evening, done: true)]), group("leo", [step("teeth", .evening)])], period: .evening)
check("the next step is the first child with something left", skip.next?.group.id ?? "nil", "leo")

// MARK: groups

let profiles: [Profile] = []
check("no profiles, no steps, no groups", String(RoutineProgressGroup.groups(profiles: profiles, steps: []).count), "0")
let shared = RoutineProgressGroup.groups(profiles: profiles, steps: [step("sweep", .morning, profile: nil)])
check("steps for nobody go to the Family group", shared.map(\.name).joined(separator: ","), "Family")

if failures > 0 { print("\n\(failures) check(s) failed"); exit(1) } else { print("\nall checks passed") }
