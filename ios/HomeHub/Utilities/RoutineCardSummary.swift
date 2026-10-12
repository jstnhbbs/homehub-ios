import Foundation

/// One person's routine steps for the day (or the household's shared ones), as the Routines card groups
/// them: children in their order, then a "Family" group for steps that belong to nobody in particular.
struct RoutineProgressGroup: Identifiable {
    let id: String
    let name: String
    let color: String
    let avatar: String?
    let steps: [RoutineStepRow]

    var completedCount: Int { steps.filter { $0.completed }.count }
    var totalCount: Int { steps.count }
    var remainingSteps: [RoutineStepRow] { steps.filter { !$0.completed } }
    var progress: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }
    var isComplete: Bool { totalCount > 0 && completedCount == totalCount }

    static func groups(profiles: [Profile], steps: [RoutineStepRow]) -> [RoutineProgressGroup] {
        let childProfiles = profiles
            .filter { $0.profileType == .child }
            .sorted { $0.sortOrder < $1.sortOrder }

        var groups = childProfiles.compactMap { profile -> RoutineProgressGroup? in
            let profileSteps = steps.filter { $0.profileId == profile.id }
            guard !profileSteps.isEmpty else { return nil }
            return RoutineProgressGroup(id: profile.id, name: profile.name, color: profile.color, avatar: profile.avatar, steps: profileSteps)
        }

        let householdSteps = steps.filter { $0.profileId == nil }
        if !householdSteps.isEmpty {
            groups.append(RoutineProgressGroup(id: "household", name: "Family", color: "#4f7c6d", avatar: nil, steps: householdSteps))
        }
        return groups
    }
}

/// What the Routines card says and in what order, so the same words and the same "next step" appear on
/// iPhone and iPad and can be checked without a screen.
struct RoutineCardSummary {
    let groups: [RoutineProgressGroup]
    /// The part of the day it is now; routines for it come first.
    let period: RoutinePeriod

    /// The part of the day for an hour (0 to 23): morning until noon, afternoon until 5, evening after.
    static func period(hour: Int) -> RoutinePeriod {
        switch hour {
        case 5..<12: .morning
        case 12..<17: .afternoon
        default: .evening
        }
    }

    /// `steps` with the current period's first, then the later parts of the day in order, then the
    /// earlier ones; finished steps go last. Steps keep their own order within each part.
    func ordered(_ steps: [RoutineStepRow]) -> [RoutineStepRow] {
        let all = RoutinePeriod.allCases
        let start = all.firstIndex(of: period) ?? 0
        func rank(_ step: RoutineStepRow) -> Int {
            let index = all.firstIndex(of: step.period) ?? 0
            return (index - start + all.count) % all.count
        }
        let indexed = steps.enumerated().map { ($0.offset, $0.element) }
        return indexed.sorted { a, b in
            if a.1.completed != b.1.completed { return !a.1.completed }
            let (ra, rb) = (rank(a.1), rank(b.1))
            return ra != rb ? ra < rb : a.0 < b.0
        }.map(\.1)
    }

    var totalSteps: Int { groups.reduce(0) { $0 + $1.totalCount } }
    var doneSteps: Int { groups.reduce(0) { $0 + $1.completedCount } }
    var isEmpty: Bool { totalSteps == 0 }
    var isAllDone: Bool { totalSteps > 0 && doneSteps == totalSteps }

    /// The big words on a Small card: how many steps are done.
    var headline: String {
        if isEmpty { return "None today" }
        return isAllDone ? "All done" : "\(doneSteps) of \(totalSteps)"
    }

    /// The first step still to do, with whose it is: the group with something left, earliest in line.
    var next: (group: RoutineProgressGroup, step: RoutineStepRow)? {
        for group in groups {
            if let step = ordered(group.steps).first(where: { !$0.completed }) {
                return (group, step)
            }
        }
        return nil
    }

    /// The line under a Small card's headline.
    func caption(display: (RoutineStepRow) -> String) -> String {
        if isEmpty { return "No routines today" }
        guard let next else { return "Nice work" }
        let multiple = groups.count > 1
        let label = display(next.step)
        return multiple ? "Next: \(label) · \(next.group.name)" : "Next: \(label)"
    }

    /// The one line above a Medium or Large card's rows.
    var line: String {
        if isEmpty { return "No routines today" }
        if isAllDone { return "All \(totalSteps) steps done" }
        return "\(doneSteps) of \(totalSteps) steps done"
    }
}
