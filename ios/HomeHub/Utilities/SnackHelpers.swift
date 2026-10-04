import Foundation

enum SnackHelpers {
    static func parseSnackOptions(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else { return [] }
        return value
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func serializeSnackOptions(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    /// Whether `profileId` has had `label` today, in a household that tracks snacks per child.
    static func isEaten(label: String, profileId: String, in records: [SnackEatenRecord]) -> Bool {
        records.contains { $0.snackLabel == label && $0.profileId == profileId }
    }

    /// Children who have had `label` today.
    static func eaterIds(label: String, among childIds: [String], in records: [SnackEatenRecord]) -> Set<String> {
        let ids = Set(records.filter { $0.snackLabel == label }.compactMap(\.profileId))
        return ids.intersection(childIds)
    }

    /// A snack counts as done once every child has had it. With no children there is nobody to
    /// have eaten it, so it is never done (rather than done for everyone).
    static func isEatenByAll(label: String, childIds: [String], in records: [SnackEatenRecord]) -> Bool {
        !childIds.isEmpty && eaterIds(label: label, among: childIds, in: records).count == childIds.count
    }

    /// "3 of 8 snacks done" counts snacks every child has had; with per-child tracking the
    /// number of individual helpings is shown alongside it by the caller.
    static func doneCount(options: [String], childIds: [String], in records: [SnackEatenRecord]) -> Int {
        options.filter { isEatenByAll(label: $0, childIds: childIds, in: records) }.count
    }

    /// Unchecked snacks first (original order), then checked snacks at the bottom.
    static func sortedSnackOptions(_ options: [String], eaten: Set<String>) -> [String] {
        let pending = options.filter { !eaten.contains($0) }
        let done = options.filter { eaten.contains($0) }
        return pending + done
    }
}
