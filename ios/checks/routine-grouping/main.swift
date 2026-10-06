import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

func profile(_ id: String, _ name: String) -> Profile {
    Profile(id: id, householdId: "h", userId: nil, profileType: .child, name: name, color: "#000", avatar: "", birthday: nil, sortOrder: 0, memberRole: nil, createdAt: nil, updatedAt: nil)
}
func routine(_ id: String, _ period: RoutinePeriod, for profileId: String?, order: Int = 0) -> Routine {
    Routine(id: id, householdId: "h", profileId: profileId, name: id, period: period, days: "0,1,2,3,4,5,6", sortOrder: order, createdAt: nil, updatedAt: nil, steps: nil)
}
func summary(_ groups: [RoutineGroup]) -> String {
    groups.map { "\($0.profile?.name ?? "Everyone"):" + $0.routines.map(\.id).joined(separator: ",") }.joined(separator: " | ")
}

let kids = [profile("a", "Ada"), profile("j", "Judah")]

check("by person, in the household's order",
      summary(RoutineGrouping.groups(routines: [routine("j1", .morning, for: "j"), routine("a1", .morning, for: "a")], profiles: kids)),
      "Ada:a1 | Judah:j1")
check("through the day within a person",
      summary(RoutineGrouping.groups(routines: [routine("bed", .evening, for: "a"), routine("am", .morning, for: "a"), routine("pm", .afternoon, for: "a")], profiles: kids)),
      "Ada:am,pm,bed")
check("two of the same part of the day keep the order they were made",
      summary(RoutineGrouping.groups(routines: [routine("second", .morning, for: "a", order: 2), routine("first", .morning, for: "a", order: 1)], profiles: kids)),
      "Ada:first,second")
check("shared routines come last",
      summary(RoutineGrouping.groups(routines: [routine("all", .morning, for: nil), routine("a1", .morning, for: "a")], profiles: kids)),
      "Ada:a1 | Everyone:all")
check("a routine for someone no longer listed is kept with the shared ones",
      summary(RoutineGrouping.groups(routines: [routine("gone", .morning, for: "zz"), routine("a1", .morning, for: "a")], profiles: kids)),
      "Ada:a1 | Everyone:gone")
check("people with no routines get no group",
      summary(RoutineGrouping.groups(routines: [routine("j1", .evening, for: "j")], profiles: kids)),
      "Judah:j1")
check("nothing at all", summary(RoutineGrouping.groups(routines: [], profiles: kids)), "")

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall routine grouping checks passed")
