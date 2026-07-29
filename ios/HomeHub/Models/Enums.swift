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

enum FoodHubSection: String, Hashable {
    case week
    case recipes
    case snacks

    var optionalModule: HubModuleId? {
        switch self {
        case .snacks: .snacks
        case .recipes: .recipes
        case .week: nil
        }
    }

    func isVisible(in modules: HubModules) -> Bool {
        guard let optionalModule else { return true }
        return modules.isEnabled(optionalModule)
    }
}

enum HubModuleId: String, Codable, Sendable, CaseIterable, Hashable {
    case routines
    case chores
    case snacks
    case recipes

    var label: String {
        switch self {
        case .routines: "Routines"
        case .chores: "Chores"
        case .snacks: "Snacks"
        case .recipes: "Recipes"
        }
    }
}

struct HubModules: Codable, Sendable, Equatable {
    var routines: Bool
    var chores: Bool
    var snacks: Bool
    var recipes: Bool

    static let defaults = HubModules(
        routines: true,
        chores: true,
        snacks: true,
        recipes: true
    )

    func isEnabled(_ module: HubModuleId) -> Bool {
        switch module {
        case .routines: routines
        case .chores: chores
        case .snacks: snacks
        case .recipes: recipes
        }
    }

    func updating(_ module: HubModuleId, enabled: Bool) -> HubModules {
        var copy = self
        switch module {
        case .routines: copy.routines = enabled
        case .chores: copy.chores = enabled
        case .snacks: copy.snacks = enabled
        case .recipes: copy.recipes = enabled
        }
        return copy
    }
}

enum HubDestination: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case routines
    case chores
    case meals
    case sleep
    case profile
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Today"
        case .calendar: "Calendar"
        case .routines: "Routines"
        case .chores: "Chores"
        case .meals: "Food"
        case .sleep: "Sleep"
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
        case .sleep: "moon.fill"
        case .profile: "person.crop.circle"
        case .settings: "gearshape.fill"
        }
    }

    var parentOnly: Bool {
        self == .settings
    }

    var showsInSidebar: Bool {
        self != .profile
    }

    var optionalModule: HubModuleId? {
        switch self {
        case .routines: .routines
        case .chores: .chores
        default: nil
        }
    }

    func isVisible(in modules: HubModules) -> Bool {
        guard showsInSidebar else { return false }
        guard let optionalModule else { return true }
        return modules.isEnabled(optionalModule)
    }
}
