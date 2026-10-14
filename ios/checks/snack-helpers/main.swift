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

func counts(_ dict: [String: Int]) -> String { dict.keys.sorted().map { "\($0)=\(dict[$0]!)" }.joined(separator: ",") }
check("per-child counts", counts(SnackHelpers.eatenCounts(options: ["Yogurt", "Apples", "Pretzels"], childIds: ["a", "b", "c"], in: records)), "a=2,b=1,c=0")
check("a deleted snack is not counted", counts(SnackHelpers.eatenCounts(options: ["Apples"], childIds: ["a", "b"], in: records)), "a=1,b=0")
check("a repeated record counts once", counts(SnackHelpers.eatenCounts(options: ["Yogurt"], childIds: ["a"], in: records + [SnackEatenRecord(snackLabel: "Yogurt", profileId: "a")])), "a=1")
check("the shared row is nobody's", counts(SnackHelpers.eatenCounts(options: ["Shared"], childIds: ["a"], in: records)), "a=0")
check("no children, no counts", counts(SnackHelpers.eatenCounts(options: ["Yogurt"], childIds: [], in: records)), "")

// existing ordering behaviour
check("unchecked first, checked last", SnackHelpers.sortedSnackOptions(["A", "B", "C"], eaten: ["A"]).joined(separator: ","), "B,C,A")

func moved(_ options: [String], _ eaten: Set<String>, _ from: Int, _ to: Int) -> String {
    SnackHelpers.movingSnack(in: options, eaten: eaten, from: from, to: to).joined(separator: ",")
}
check("move down one", moved(["A", "B", "C", "D"], [], 0, 2), "B,A,C,D")
check("move to the end", moved(["A", "B", "C", "D"], [], 0, 4), "B,C,D,A")
check("move up to the top", moved(["A", "B", "C", "D"], [], 3, 0), "D,A,B,C")
check("dropped where it was", moved(["A", "B", "C"], [], 1, 1), "A,B,C")
check("dropped just below itself", moved(["A", "B", "C"], [], 1, 2), "A,B,C")
check("out of range changes nothing", moved(["A", "B"], [], 5, 0), "A,B")
check("eaten snacks are shown last: drag a pending one to the end", moved(["A", "B", "C", "D"], ["A"], 0, 3), "A,C,D,B")
check("dragging above an eaten snack puts it before that one", moved(["A", "B", "C", "D"], ["B"], 2, 2), "A,B,C,D")
check("an eaten snack stays below the pending ones", moved(["A", "B", "C", "D"], ["D"], 3, 0), "A,B,C,D")
check("eaten snacks reorder among themselves", moved(["A", "B", "C", "D"], ["C", "D"], 3, 2), "A,B,D,C")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
