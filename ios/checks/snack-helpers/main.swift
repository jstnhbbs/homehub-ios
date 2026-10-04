import Foundation

struct SnackEatenRecord: Hashable {
    let snackLabel: String
    var profileId: String?
}

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

let records = [
    SnackEatenRecord(snackLabel: "Yogurt", profileId: "a"),
    SnackEatenRecord(snackLabel: "Yogurt", profileId: "b"),
    SnackEatenRecord(snackLabel: "Apples", profileId: "a"),
    SnackEatenRecord(snackLabel: "Gone", profileId: "deleted"),
    SnackEatenRecord(snackLabel: "Shared", profileId: nil),
]

check("a child who ate it", String(SnackHelpers.isEaten(label: "Yogurt", profileId: "a", in: records)), "true")
check("a child who did not", String(SnackHelpers.isEaten(label: "Apples", profileId: "b", in: records)), "false")
check("the same child, a different snack", String(SnackHelpers.isEaten(label: "Apples", profileId: "a", in: records)), "true")

check("eaters only among current children", String(SnackHelpers.eaterIds(label: "Gone", among: ["a", "b"], in: records).count), "0")
check("two eaters", String(SnackHelpers.eaterIds(label: "Yogurt", among: ["a", "b"], in: records).count), "2")
check("the shared row is nobody's helping", String(SnackHelpers.eaterIds(label: "Shared", among: ["a", "b"], in: records).count), "0")

check("everyone had it: done", String(SnackHelpers.isEatenByAll(label: "Yogurt", childIds: ["a", "b"], in: records)), "true")
check("only one of two: not done", String(SnackHelpers.isEatenByAll(label: "Apples", childIds: ["a", "b"], in: records)), "false")
check("a third child who has not: not done", String(SnackHelpers.isEatenByAll(label: "Yogurt", childIds: ["a", "b", "c"], in: records)), "false")
check("one child, who had it: done", String(SnackHelpers.isEatenByAll(label: "Apples", childIds: ["a"], in: records)), "true")
check("no children: never done", String(SnackHelpers.isEatenByAll(label: "Yogurt", childIds: [], in: records)), "false")

check("done count across a list", String(SnackHelpers.doneCount(options: ["Yogurt", "Apples", "Pretzels"], childIds: ["a", "b"], in: records)), "1")
check("done count with nothing eaten", String(SnackHelpers.doneCount(options: ["Pretzels"], childIds: ["a", "b"], in: [])), "0")

// existing ordering behaviour
check("unchecked first, checked last", SnackHelpers.sortedSnackOptions(["A", "B", "C"], eaten: ["A"]).joined(separator: ","), "B,C,A")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
