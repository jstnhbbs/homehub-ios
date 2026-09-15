import Foundation

struct HomeHubWidgetSummary: Codable, Sendable, Equatable {
    var householdName: String
    var localDate: String
    var pendingRoutineCount: Int
    var pendingChoreCount: Int
    var dinnerTitle: String?
    var nextEventTitle: String?
    var nextEventTime: String?
    var weatherTemperature: Int?
    var weatherCondition: String?
    var updatedAt: Date
}

extension HomeHubWidgetSummary {
    static let placeholder = HomeHubWidgetSummary(
        householdName: "Beacon",
        localDate: "Today",
        pendingRoutineCount: 3,
        pendingChoreCount: 2,
        dinnerTitle: "Spaghetti night",
        nextEventTitle: "Soccer practice",
        nextEventTime: "5:30 PM",
        weatherTemperature: 72,
        weatherCondition: "Sunny",
        updatedAt: .now
    )
}

enum HomeHubWidgetStore {
    static func save(_ summary: HomeHubWidgetSummary) {}

    static func load() -> HomeHubWidgetSummary? {
        nil
    }

    static func clear() {}
}
