import Foundation

enum HouseholdRole: String, Codable, Sendable {
    case owner
    case parent
    case guest
}

enum ProfileType: String, Codable, Sendable {
    case adult
    case child
}

enum RoutinePeriod: String, Codable, Sendable, CaseIterable {
    case morning
    case afternoon
    case evening

    var label: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }
}

enum ChoreCadence: String, Codable, Sendable {
    case daily
    case weekly
}

enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var label: String {
        rawValue.capitalized
    }
}

enum CalendarProvider: String, Codable, Sendable {
    case icloud
    case google
}

enum CalendarConnectionStatus: String, Codable, Sendable {
    case connected
    case syncing
    case error
}

enum HubDestination: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case routines
    case chores
    case meals
    case snacks
    case recipes
    case profile
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Today"
        case .calendar: "Calendar"
        case .routines: "Routines"
        case .chores: "Chores"
        case .meals: "Meals"
        case .snacks: "Snacks"
        case .recipes: "Recipes"
        case .profile: "Profile"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .calendar: "calendar"
        case .routines: "checklist"
        case .chores: "checkmark.square.fill"
        case .meals: "fork.knife"
        case .snacks: "carrot.fill"
        case .recipes: "book.fill"
        case .profile: "person.crop.circle"
        case .settings: "gearshape.fill"
        }
    }

    var parentOnly: Bool {
        self == .settings
    }
}
