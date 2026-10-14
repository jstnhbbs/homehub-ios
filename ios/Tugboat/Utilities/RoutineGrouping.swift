import Foundation

/// One person's routines, or the household's own, for the Routines page.
struct RoutineGroup: Identifiable {
    let id: String
    /// Nil for routines that belong to everyone.
    let profile: Profile?
    let routines: [Routine]
}

enum RoutineGrouping {
    /// Routines grouped by the person they are for, in the order people are listed in the
    /// household, with the shared ones last. Within a group they run through the day: morning,
    /// after school, bedtime, then in the order they were made.
    static func groups(routines: [Routine], profiles: [Profile]) -> [RoutineGroup] {
        let periodOrder = Dictionary(uniqueKeysWithValues: RoutinePeriod.allCases.enumerated().map { ($1, $0) })
        func sorted(_ list: [Routine]) -> [Routine] {
            list.sorted {
                let first = periodOrder[$0.period] ?? 0
                let second = periodOrder[$1.period] ?? 0
                return first == second ? $0.sortOrder < $1.sortOrder : first < second
            }
        }

        let known = Set(profiles.map(\.id))
        var result = profiles.compactMap { profile -> RoutineGroup? in
            let own = routines.filter { $0.profileId == profile.id }
            return own.isEmpty ? nil : RoutineGroup(id: profile.id, profile: profile, routines: sorted(own))
        }
        // Everyone's, plus any routine whose person is no longer in the list.
        let shared = routines.filter { $0.profileId == nil || !known.contains($0.profileId ?? "") }
        if !shared.isEmpty {
            result.append(RoutineGroup(id: "everyone", profile: nil, routines: sorted(shared)))
        }
        return result
    }
}
