import Foundation

enum HouseholdWidgetKind: String, CaseIterable, Sendable {
    case next, routines, chores, dinner, sleep, notes, groceries, celebrations, overview

    var title: String {
        switch self {
        case .next: "Up Next"
        case .routines: "Child's Routines"
        case .chores: "Chores"
        case .dinner: "Tonight's Dinner"
        case .sleep: "Sleep"
        case .notes: "Household Note"
        case .groceries: "Groceries"
        case .celebrations: "Celebrations"
        case .overview: "Household Snapshot"
        }
    }

    var destination: String {
        switch self {
        case .next, .overview: "dashboard"
        case .routines: "routines"
        case .chores: "chores"
        case .dinner: "meals"
        case .sleep: "sleep"
        case .notes: "notes"
        case .groceries: "groceries"
        case .celebrations: "birthdays"
        }
    }

    var symbol: String {
        switch self {
        case .next: "clock"
        case .routines: "checklist"
        case .chores: "checkmark.square"
        case .dinner: "fork.knife"
        case .sleep: "moon.zzz.fill"
        case .notes: "note.text"
        case .groceries: "basket"
        case .celebrations: "gift"
        case .overview: "house"
        }
    }
}

/// Only display data, never credentials, email addresses, invite codes or complete API responses.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    var version = 1
    var userId: String
    var householdId: String
    var householdName: String
    var timezone: String
    var localDate: String
    var updatedAt: Date
    var accentLight: String
    var accentDark: String
    var enabledDestinations: [String]
    var people: [Person]
    var steps: [Step]
    var chores: [Chore]
    var events: [Event]
    var dinner: Dinner?
    var sleeps: [Sleep]
    var notes: [Note]
    var groceries: [String]
    var groceryCount: Int
    var celebrations: [Celebration]
    var actionError: String?

    struct Person: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var name: String
        var color: String
        var isChild: Bool
    }
    struct Step: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var label: String
        var personId: String?
        var period: String
        var completed: Bool
    }
    struct Chore: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var title: String
        var personId: String?
        var periodKey: String
        var dueAt: Date?
        var completed: Bool
    }
    struct Event: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var allDay: Bool
    }
    struct Dinner: Codable, Equatable, Sendable {
        var title: String
        var recipeId: String?
        var imageURL: String?
    }
    struct Sleep: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var personId: String
        var start: Date
        var end: Date?
        var kind: String
    }
    struct Note: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var title: String
        var body: String
        var pinned: Bool
    }
    struct Celebration: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var name: String
        var date: String
        var years: Int
        var isAnniversary: Bool
    }

    var timeZone: TimeZone { TimeZone(identifier: timezone) ?? .current }
    func isCurrentDay(at date: Date) -> Bool { Self.localDate(date, timezone: timeZone) == localDate }
    static func localDate(_ date: Date, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    func personName(_ id: String?) -> String {
        people.first { $0.id == id }?.name ?? "Everyone"
    }
    func routineSteps(personId: String?, at now: Date? = nil) -> [Step] {
        let selected = personId.map { id in steps.filter { $0.personId == id || $0.personId == nil } } ?? steps
        guard let now else { return selected }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: now)
        let order = hour < 12 ? ["morning", "afternoon", "evening"] : (hour < 17 ? ["afternoon", "evening", "morning"] : ["evening", "morning", "afternoon"])
        return selected.enumerated().sorted {
            let left = order.firstIndex(of: $0.element.period) ?? 3
            let right = order.firstIndex(of: $1.element.period) ?? 3
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }
    func selectedNote(id: String?) -> Note? {
        if let id { return notes.first { $0.id == id } }
        return notes.first(where: \.pinned) ?? notes.first
    }
    func sleepMinutes(on date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return sleeps.reduce(0) { total, log in
            guard let stopped = log.end else { return total }
            return total + max(0, Int(min(stopped, end).timeIntervalSince(max(log.start, start)) / 60))
        }
    }
    func upcoming(at now: Date) -> [Upcoming] {
        guard isCurrentDay(at: now) else { return [] }
        var result = events.filter { !$0.allDay && $0.end > now }.map {
            Upcoming(id: "event:\($0.id)", title: $0.title, detail: $0.start <= now ? "Now" : "Calendar",
                     start: $0.start, destination: "calendar")
        }
        result += chores.filter { !$0.completed && $0.dueAt != nil }.map {
            Upcoming(id: "chore:\($0.id)", title: $0.title, detail: $0.dueAt! < now ? "Overdue" : personName($0.personId),
                     start: $0.dueAt!, destination: "chores")
        }
        result.sort { $0.start == $1.start ? $0.id < $1.id : ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
        if result.isEmpty, let next = routineSteps(personId: nil, at: now).first(where: { !$0.completed }) {
            result = [Upcoming(id: "routine:\(next.id)", title: next.label, detail: personName(next.personId),
                               start: nil, destination: "routines")]
        }
        return result
    }
    struct Upcoming: Identifiable, Sendable {
        var id: String
        var title: String
        var detail: String
        var start: Date?
        var destination: String
    }
}

enum WidgetRoute {
    static let destinations: Set<String> = ["dashboard", "calendar", "routines", "chores", "meals", "sleep", "notes", "groceries", "birthdays"]
    static func url(destination: String, recipeId: String? = nil) -> URL {
        var components = URLComponents(string: "tugboat://widget/\(destinations.contains(destination) ? destination : "dashboard")")!
        if destination == "meals", let recipeId, UUID(uuidString: recipeId) != nil {
            components.queryItems = [URLQueryItem(name: "recipe", value: recipeId)]
        }
        return components.url!
    }
    static func destination(from url: URL) -> String? {
        guard url.scheme == "tugboat", url.host == "widget", url.fragment == nil else { return nil }
        let value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if url.query != nil, value != "meals" || recipeId(from: url) == nil { return nil }
        return destinations.contains(value) ? value : nil
    }
    static func recipeId(from url: URL) -> String? {
        guard url.scheme == "tugboat", url.host == "widget", url.path == "/meals",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "recipe", let value = items[0].value,
              UUID(uuidString: value) != nil else { return nil }
        return value
    }
}

enum WidgetActionPolicy {
    static func appliesCompletion(action: String, writtenDay: String, currentDay: String,
                                  writtenPeriod: String? = nil, currentPeriod: String? = nil) -> Bool {
        if action == "step" { return writtenDay == currentDay }
        if action == "chore" { return writtenPeriod != nil && writtenPeriod == currentPeriod }
        return false
    }
    static func allows(action: String, itemId: String, userId: String, householdId: String,
                       localDate: String, current: WidgetSnapshot, now: Date = .now) -> Bool {
        guard current.userId == userId, current.householdId == householdId else { return false }
        switch action {
        case "refresh": return true
        case "endSleep": return current.sleeps.contains { $0.id == itemId && $0.end == nil }
        case "step": return current.isCurrentDay(at: now) && localDate == current.localDate && current.steps.contains { $0.id == itemId }
        case "chore": return current.isCurrentDay(at: now) && localDate == current.localDate && current.chores.contains { $0.id == itemId }
        default: return false
        }
    }
}
