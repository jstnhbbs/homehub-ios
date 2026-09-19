import Foundation

enum HouseholdRole: String, Codable, Sendable, CaseIterable {
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
    case local
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
    case notes
    case calendar
    case groceries
    case routines
    case chores
    case meals
    case sleep
    case birthdays
    case snacks
    case recipes

    var label: String {
        switch self {
        case .notes: "Notes"
        case .calendar: "Calendar"
        case .groceries: "Groceries"
        case .routines: "Routines"
        case .chores: "Chores"
        case .meals: "Food"
        case .sleep: "Sleep"
        case .birthdays: "Birthdays"
        case .snacks: "Snacks"
        case .recipes: "Recipes"
        }
    }

    var systemImage: String {
        switch self {
        case .notes: "note.text"
        case .calendar: "calendar"
        case .groceries: "list.bullet.clipboard.fill"
        case .routines: "checklist"
        case .chores: "checkmark.square.fill"
        case .meals: "fork.knife"
        case .sleep: "moon.fill"
        case .birthdays: "gift.fill"
        case .snacks: "carrot.fill"
        case .recipes: "book.closed.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "shopping", "groceries":
            self = .groceries
        case "notes":
            self = .notes
        case "calendar":
            self = .calendar
        case "routines":
            self = .routines
        case "chores":
            self = .chores
        case "meals":
            self = .meals
        case "sleep":
            self = .sleep
        case "birthdays":
            self = .birthdays
        case "snacks":
            self = .snacks
        case "recipes":
            self = .recipes
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown HubModuleId: \(raw)")
            )
        }
    }
}

enum DashboardCardId: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case weather
    case schedule
    case routines
    case chores
    case meals
    case snacks
    case sleep
    case groceries
    case notes
    case birthdays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weather: "Weather"
        case .schedule: "Today's Schedule"
        case .routines: "Today's Routines"
        case .chores: "Chores"
        case .meals: "Today's Meals"
        case .snacks: "Snacks"
        case .sleep: "Sleep"
        case .groceries: "Groceries"
        case .notes: "Notes"
        case .birthdays: "Birthdays"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "shopping", "groceries":
            self = .groceries
        case "weather":
            self = .weather
        case "schedule":
            self = .schedule
        case "routines":
            self = .routines
        case "chores":
            self = .chores
        case "meals":
            self = .meals
        case "snacks":
            self = .snacks
        case "sleep":
            self = .sleep
        case "notes":
            self = .notes
        case "birthdays":
            self = .birthdays
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown DashboardCardId: \(raw)")
            )
        }
    }

    var systemImage: String {
        switch self {
        case .weather: "cloud.sun.fill"
        case .schedule: "calendar"
        case .routines: "checklist"
        case .chores: "checkmark.square.fill"
        case .meals: "fork.knife"
        case .snacks: "carrot.fill"
        case .sleep: "moon.fill"
        case .groceries: "list.bullet.clipboard.fill"
        case .notes: "note.text"
        case .birthdays: "gift.fill"
        }
    }

    var destination: HubDestination? {
        switch self {
        case .weather: nil
        case .schedule: .calendar
        case .routines: .routines
        case .chores: .chores
        case .meals, .snacks: .meals
        case .sleep: .sleep
        case .groceries: .groceries
        case .notes: .notes
        case .birthdays: .birthdays
        }
    }

    var requiredModule: HubModuleId? {
        switch self {
        case .weather: nil
        case .schedule: .calendar
        case .routines: .routines
        case .chores: .chores
        case .meals: .meals
        case .snacks: .snacks
        case .sleep: .sleep
        case .groceries: .groceries
        case .notes: .notes
        case .birthdays: .birthdays
        }
    }
}

enum DashboardCardSize: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case compact
    case standard
    case expanded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Standard"
        case .standard: "Standard"
        case .expanded: "Expanded"
        }
    }

    static let layoutOptions: [DashboardCardSize] = [.standard, .expanded]

}

struct HubModules: Codable, Sendable, Equatable {
    var notes: Bool
    var calendar: Bool
    var groceries: Bool
    var routines: Bool
    var chores: Bool
    var meals: Bool
    var sleep: Bool
    var birthdays: Bool
    var snacks: Bool
    var recipes: Bool
    var sidebarOrder: [HubModuleId]
    var dashboardCards: [DashboardCardId: Bool]
    var dashboardCardSizes: [DashboardCardId: DashboardCardSize]
    var dashboardOrder: [DashboardCardId]

    static let defaults = HubModules(
        notes: true,
        calendar: true,
        groceries: true,
        routines: true,
        chores: true,
        meals: true,
        sleep: true,
        birthdays: true,
        snacks: true,
        recipes: true,
        sidebarOrder: [.notes, .calendar, .groceries, .routines, .chores, .meals, .sleep, .birthdays],
        dashboardCards: Dictionary(uniqueKeysWithValues: DashboardCardId.allCases.map { ($0, true) }),
        dashboardCardSizes: Dictionary(uniqueKeysWithValues: DashboardCardId.allCases.map { ($0, .standard) }),
        dashboardOrder: [.weather, .schedule, .routines, .chores, .meals, .snacks, .sleep, .groceries, .notes, .birthdays]
    )

    private enum CodingKeys: String, CodingKey {
        case notes
        case calendar
        case groceries
        case shopping
        case routines
        case chores
        case meals
        case sleep
        case birthdays
        case snacks
        case recipes
        case sidebarOrder
        case dashboardCards
        case dashboardCardSizes
        case dashboardOrder
    }

    init(
        notes: Bool,
        calendar: Bool,
        groceries: Bool,
        routines: Bool,
        chores: Bool,
        meals: Bool,
        sleep: Bool,
        birthdays: Bool,
        snacks: Bool,
        recipes: Bool,
        sidebarOrder: [HubModuleId],
        dashboardCards: [DashboardCardId: Bool],
        dashboardCardSizes: [DashboardCardId: DashboardCardSize],
        dashboardOrder: [DashboardCardId]
    ) {
        self.notes = notes
        self.calendar = calendar
        self.groceries = groceries
        self.routines = routines
        self.chores = chores
        self.meals = meals
        self.sleep = sleep
        self.birthdays = birthdays
        self.snacks = snacks
        self.recipes = recipes
        self.sidebarOrder = Self.normalizedOrder(
            sidebarOrder,
            fallback: Self.defaultsSidebarOrder,
            allowed: Self.sidebarModules
        )
        self.dashboardCards = Self.normalizedDashboardCards(dashboardCards)
        self.dashboardCardSizes = Self.normalizedDashboardCardSizes(dashboardCardSizes)
        self.dashboardOrder = Self.normalizedOrder(
            dashboardOrder,
            fallback: Self.defaultsDashboardOrder,
            allowed: Array(DashboardCardId.allCases)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dashboardCardValues = try container.decodeIfPresent(
            [String: Bool].self,
            forKey: .dashboardCards
        ) ?? Dictionary(uniqueKeysWithValues: Self.defaults.dashboardCards.map { ($0.key.rawValue, $0.value) })
        let dashboardCardSizeValues = try container.decodeIfPresent(
            [String: String].self,
            forKey: .dashboardCardSizes
        ) ?? Dictionary(uniqueKeysWithValues: Self.defaults.dashboardCardSizes.map { ($0.key.rawValue, $0.value.rawValue) })
        let groceriesEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .groceries)
            ?? container.decodeIfPresent(Bool.self, forKey: .shopping)
            ?? Self.defaults.groceries
        self.init(
            notes: try container.decodeIfPresent(Bool.self, forKey: .notes) ?? Self.defaults.notes,
            calendar: try container.decodeIfPresent(Bool.self, forKey: .calendar) ?? Self.defaults.calendar,
            groceries: groceriesEnabled,
            routines: try container.decodeIfPresent(Bool.self, forKey: .routines) ?? Self.defaults.routines,
            chores: try container.decodeIfPresent(Bool.self, forKey: .chores) ?? Self.defaults.chores,
            meals: try container.decodeIfPresent(Bool.self, forKey: .meals) ?? Self.defaults.meals,
            sleep: try container.decodeIfPresent(Bool.self, forKey: .sleep) ?? Self.defaults.sleep,
            birthdays: try container.decodeIfPresent(Bool.self, forKey: .birthdays) ?? Self.defaults.birthdays,
            snacks: try container.decodeIfPresent(Bool.self, forKey: .snacks) ?? Self.defaults.snacks,
            recipes: try container.decodeIfPresent(Bool.self, forKey: .recipes) ?? Self.defaults.recipes,
            sidebarOrder: try container.decodeIfPresent([HubModuleId].self, forKey: .sidebarOrder) ?? Self.defaultsSidebarOrder,
            dashboardCards: Dictionary(
                uniqueKeysWithValues: dashboardCardValues.compactMap { key, value in
                    let normalizedKey = key == "shopping" ? "groceries" : key
                    return DashboardCardId(rawValue: normalizedKey).map { ($0, value) }
                }
            ),
            dashboardCardSizes: Dictionary(
                uniqueKeysWithValues: dashboardCardSizeValues.compactMap { key, value in
                    let normalizedKey = key == "shopping" ? "groceries" : key
                    guard let card = DashboardCardId(rawValue: normalizedKey),
                          let size = DashboardCardSize(rawValue: value) else {
                        return nil
                    }
                    return (card, size)
                }
            ),
            dashboardOrder: try container.decodeIfPresent([DashboardCardId].self, forKey: .dashboardOrder) ?? Self.defaultsDashboardOrder
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notes, forKey: .notes)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(groceries, forKey: .groceries)
        try container.encode(routines, forKey: .routines)
        try container.encode(chores, forKey: .chores)
        try container.encode(meals, forKey: .meals)
        try container.encode(sleep, forKey: .sleep)
        try container.encode(birthdays, forKey: .birthdays)
        try container.encode(snacks, forKey: .snacks)
        try container.encode(recipes, forKey: .recipes)
        try container.encode(sidebarOrder, forKey: .sidebarOrder)
        try container.encode(
            Dictionary(uniqueKeysWithValues: dashboardCards.map { ($0.key.rawValue, $0.value) }),
            forKey: .dashboardCards
        )
        try container.encode(
            Dictionary(uniqueKeysWithValues: dashboardCardSizes.map { ($0.key.rawValue, $0.value.rawValue) }),
            forKey: .dashboardCardSizes
        )
        try container.encode(dashboardOrder, forKey: .dashboardOrder)
    }

    static let sidebarModules: [HubModuleId] = [.notes, .calendar, .groceries, .routines, .chores, .meals, .sleep, .birthdays]
    static let foodModules: [HubModuleId] = [.snacks, .recipes]
    private static let defaultsSidebarOrder: [HubModuleId] = [.notes, .calendar, .groceries, .routines, .chores, .meals, .sleep, .birthdays]
    private static let defaultsDashboardOrder: [DashboardCardId] = [.weather, .schedule, .routines, .chores, .meals, .snacks, .sleep, .groceries, .notes, .birthdays]

    func isEnabled(_ module: HubModuleId) -> Bool {
        switch module {
        case .notes: notes
        case .calendar: calendar
        case .groceries: groceries
        case .routines: routines
        case .chores: chores
        case .meals: meals
        case .sleep: sleep
        case .birthdays: birthdays
        case .snacks: snacks
        case .recipes: recipes
        }
    }

    func isDashboardCardEnabled(_ card: DashboardCardId) -> Bool {
        guard let requiredModule = card.requiredModule else {
            return dashboardCards[card, default: true]
        }
        return dashboardCards[card, default: true] && isEnabled(requiredModule)
    }

    func updating(_ module: HubModuleId, enabled: Bool) -> HubModules {
        var copy = self
        switch module {
        case .notes: copy.notes = enabled
        case .calendar: copy.calendar = enabled
        case .groceries: copy.groceries = enabled
        case .routines: copy.routines = enabled
        case .chores: copy.chores = enabled
        case .meals: copy.meals = enabled
        case .sleep: copy.sleep = enabled
        case .birthdays: copy.birthdays = enabled
        case .snacks: copy.snacks = enabled
        case .recipes: copy.recipes = enabled
        }
        return copy
    }

    func updatingDashboardCard(_ card: DashboardCardId, enabled: Bool) -> HubModules {
        var copy = self
        copy.dashboardCards[card] = enabled
        return copy
    }

    func updatingDashboardCardSize(_ card: DashboardCardId, size: DashboardCardSize) -> HubModules {
        var copy = self
        copy.dashboardCardSizes[card] = size
        return copy
    }

    func dashboardCardSize(_ card: DashboardCardId) -> DashboardCardSize {
        dashboardCardSizes[card, default: .standard]
    }

    func movingSidebarModule(_ module: HubModuleId, by offset: Int) -> HubModules {
        var copy = self
        copy.sidebarOrder = Self.moving(module, in: sidebarOrder, by: offset)
        return copy
    }

    func movingDashboardCard(_ card: DashboardCardId, by offset: Int) -> HubModules {
        var copy = self
        copy.dashboardOrder = Self.moving(card, in: dashboardOrder, by: offset)
        return copy
    }

    private static func normalizedDashboardCards(_ cards: [DashboardCardId: Bool]) -> [DashboardCardId: Bool] {
        var normalized = Dictionary(uniqueKeysWithValues: DashboardCardId.allCases.map { ($0, true) })
        for card in DashboardCardId.allCases {
            if let enabled = cards[card] {
                normalized[card] = enabled
            }
        }
        return normalized
    }

    private static func normalizedDashboardCardSizes(_ sizes: [DashboardCardId: DashboardCardSize]) -> [DashboardCardId: DashboardCardSize] {
        var normalized = Dictionary(uniqueKeysWithValues: DashboardCardId.allCases.map { ($0, DashboardCardSize.standard) })
        for card in DashboardCardId.allCases {
            if let size = sizes[card] {
                normalized[card] = size
            }
        }
        return normalized
    }

    private static func normalizedOrder<T: Hashable>(_ order: [T], fallback: [T], allowed: [T]) -> [T] {
        var seen = Set<T>()
        let allowedSet = Set(allowed)
        var normalized = order.filter { item in
            allowedSet.contains(item) && seen.insert(item).inserted
        }
        for item in fallback where !seen.contains(item) {
            normalized.append(item)
            seen.insert(item)
        }
        return normalized
    }

    private static func moving<T: Equatable>(_ item: T, in order: [T], by offset: Int) -> [T] {
        guard let index = order.firstIndex(of: item) else { return order }
        let destination = max(0, min(order.count - 1, index + offset))
        guard destination != index else { return order }
        var copy = order
        copy.remove(at: index)
        copy.insert(item, at: destination)
        return copy
    }
}

enum HubDestination: String, Hashable, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case groceries
    case routines
    case chores
    case meals
    case sleep
    case birthdays
    case notes
    case profile
    case settings
    case more

    var id: String { rawValue }

    init?(module: HubModuleId) {
        switch module {
        case .notes:
            self = .notes
        case .calendar:
            self = .calendar
        case .groceries:
            self = .groceries
        case .routines:
            self = .routines
        case .chores:
            self = .chores
        case .meals:
            self = .meals
        case .sleep:
            self = .sleep
        case .birthdays:
            self = .birthdays
        case .snacks, .recipes:
            return nil
        }
    }

    var label: String {
        switch self {
        case .dashboard: "Today"
        case .calendar: "Calendar"
        case .groceries: "Groceries"
        case .routines: "Routines"
        case .chores: "Chores"
        case .meals: "Food"
        case .sleep: "Sleep"
        case .birthdays: "Birthdays"
        case .notes: "Notes"
        case .profile: "Profile"
        case .settings: "Settings"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .calendar: "calendar"
        case .groceries: "list.bullet.clipboard.fill"
        case .routines: "checklist"
        case .chores: "checkmark.square.fill"
        case .meals: "fork.knife"
        case .sleep: "moon.fill"
        case .birthdays: "gift.fill"
        case .notes: "note.text"
        case .profile: "person.crop.circle"
        case .settings: "gearshape.fill"
        case .more: "ellipsis"
        }
    }

    var showsInSidebar: Bool {
        self != .profile && self != .more
    }

    var optionalModule: HubModuleId? {
        switch self {
        case .notes: .notes
        case .calendar: .calendar
        case .groceries: .groceries
        case .routines: .routines
        case .chores: .chores
        case .meals: .meals
        case .sleep: .sleep
        case .birthdays: .birthdays
        default: nil
        }
    }

    func isVisible(in modules: HubModules) -> Bool {
        if self == .more { return true }
        guard showsInSidebar else { return false }
        guard let optionalModule else { return true }
        return modules.isEnabled(optionalModule)
    }
}
