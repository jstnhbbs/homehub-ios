import Foundation

enum LockWidgetKind: String, CaseIterable {
    // Keep today and evening as stored identifiers for widgets already on a Lock Screen.
    case today, sleep, evening, groceries, celebrations, chores

    var title: String {
        switch self {
        case .today: "Coming Up"
        case .sleep: "Sleep"
        case .evening: "Tonight's Dinner"
        case .groceries: "Groceries"
        case .celebrations: "Celebrations"
        case .chores: "Chores"
        }
    }

    var destination: String {
        switch self {
        case .today: "dashboard"
        case .sleep: "sleep"
        case .evening: "meals"
        case .groceries: "groceries"
        case .celebrations: "birthdays"
        case .chores: "chores"
        }
    }

    var requiresCurrentDay: Bool { self == .today || self == .evening || self == .chores }

    func isEnabled(in snapshot: WidgetSnapshot) -> Bool {
        destination == "dashboard" || snapshot.enabledDestinations.contains(destination)
    }

    func url(in snapshot: WidgetSnapshot?, at date: Date) -> URL {
        if self == .today, let next = snapshot?.upcoming(at: date).first {
            return WidgetRoute.url(destination: next.destination)
        }
        return WidgetRoute.url(destination: destination,
                               recipeId: self == .evening && snapshot?.isCurrentDay(at: date) == true ? snapshot?.dinner?.recipeId : nil)
    }
}

enum LockWidgetContent {
    static func status(for item: WidgetSnapshot.Upcoming) -> String {
        switch item.detail {
        case "Now": "Now"
        case "Overdue": "Overdue"
        default: "Coming Up"
        }
    }

    static func validChild(_ id: String?, in snapshot: WidgetSnapshot) -> Bool {
        id == nil || snapshot.people.contains { $0.id == id && $0.isChild }
    }

    static func sleeping(in snapshot: WidgetSnapshot, childId: String?) -> [WidgetSnapshot.Sleep] {
        snapshot.sleeps.filter { $0.end == nil && (childId == nil || $0.personId == childId) }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    struct AwakeChild {
        let id: String
        let name: String
        let since: Date
    }

    static func awake(in snapshot: WidgetSnapshot, childId: String?, at date: Date) -> [AwakeChild] {
        let sleepingIds = Set(sleeping(in: snapshot, childId: nil).map(\.personId))
        return snapshot.people.filter {
            $0.isChild && !sleepingIds.contains($0.id) && (childId == nil || $0.id == childId)
        }.compactMap { person in
            guard let last = snapshot.sleeps.filter({ $0.personId == person.id }).compactMap(\.end).filter({ $0 <= date }).max() else { return nil }
            return AwakeChild(id: person.id, name: person.name, since: last)
        }.sorted { $0.since == $1.since ? $0.id < $1.id : $0.since < $1.since }
    }

    static func nextCelebration(in snapshot: WidgetSnapshot, at date: Date) -> (item: WidgetSnapshot.Celebration, days: Int)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone
        let today = calendar.startOfDay(for: date)
        return snapshot.celebrations.compactMap { item -> (item: WidgetSnapshot.Celebration, days: Int)? in
            let parts = item.date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])), day >= today else { return nil }
            return (item, calendar.dateComponents([.day], from: today, to: day).day ?? 0)
        }.min { $0.days == $1.days ? $0.item.id < $1.item.id : $0.days < $1.days }
    }
}
