import Foundation
import SwiftUI

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
        case .birthdays: CelebrationNaming.current
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
        case .birthdays: CelebrationNaming.current
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

/// The dashboard grid is arranged and sized separately for iPhone and for iPad/Mac, since the
/// two have very different amounts of room. This technically follows SwiftUI's horizontal size
/// class, so an iPad in a narrow split-screen window uses `.phone` too — but for how someone
/// actually uses the app, this is iPhone vs iPad/Mac.
enum DashboardLayoutTarget: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case phone
    case tablet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .phone: "iPhone"
        case .tablet: "iPad & Mac"
        }
    }

    init(horizontalSizeClass: UserInterfaceSizeClass?) {
        self = horizontalSizeClass == .compact ? .phone : .tablet
    }
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
    /// Which dashboard cards are turned on. Shared: the same set shows on every device.
    var dashboardCards: [DashboardCardId: Bool]
    var dashboardCardSizesPhone: [DashboardCardId: DashboardCardSize]
    var dashboardOrderPhone: [DashboardCardId]
    var dashboardCardSizesTablet: [DashboardCardId: DashboardCardSize]
    var dashboardOrderTablet: [DashboardCardId]

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
        // Phone and tablet start out identical; they only diverge once someone edits one of them.
        dashboardCardSizesPhone: Self.defaultsDashboardCardSizes,
        dashboardOrderPhone: Self.defaultsDashboardOrder,
        dashboardCardSizesTablet: Self.defaultsDashboardCardSizes,
        dashboardOrderTablet: Self.defaultsDashboardOrder
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
        case dashboardCardSizesPhone
        case dashboardOrderPhone
        case dashboardCardSizesTablet
        case dashboardOrderTablet
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
        dashboardCardSizesPhone: [DashboardCardId: DashboardCardSize],
        dashboardOrderPhone: [DashboardCardId],
        dashboardCardSizesTablet: [DashboardCardId: DashboardCardSize],
        dashboardOrderTablet: [DashboardCardId]
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
        self.dashboardCardSizesPhone = Self.normalizedDashboardCardSizes(dashboardCardSizesPhone)
        self.dashboardOrderPhone = Self.normalizedOrder(
            dashboardOrderPhone,
            fallback: Self.defaultsDashboardOrder,
            allowed: Array(DashboardCardId.allCases)
        )
        self.dashboardCardSizesTablet = Self.normalizedDashboardCardSizes(dashboardCardSizesTablet)
        self.dashboardOrderTablet = Self.normalizedOrder(
            dashboardOrderTablet,
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
        let groceriesEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .groceries)
            ?? container.decodeIfPresent(Bool.self, forKey: .shopping)
            ?? Self.defaults.groceries
        // A locally cached dashboard written by a build from before per-device layouts existed
        // has neither of these keys; that's fine, `init` falls back to `defaults` for whichever
        // is missing, and the next successful server refresh replaces the cache anyway.
        let dashboardCardSizesPhoneValues = try container.decodeIfPresent([String: String].self, forKey: .dashboardCardSizesPhone)
        let dashboardCardSizesTabletValues = try container.decodeIfPresent([String: String].self, forKey: .dashboardCardSizesTablet)
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
            dashboardCardSizesPhone: dashboardCardSizesPhoneValues.map(Self.decodedDashboardCardSizes)
                ?? Self.defaults.dashboardCardSizesPhone,
            dashboardOrderPhone: try container.decodeIfPresent([DashboardCardId].self, forKey: .dashboardOrderPhone) ?? Self.defaultsDashboardOrder,
            dashboardCardSizesTablet: dashboardCardSizesTabletValues.map(Self.decodedDashboardCardSizes)
                ?? Self.defaults.dashboardCardSizesTablet,
            dashboardOrderTablet: try container.decodeIfPresent([DashboardCardId].self, forKey: .dashboardOrderTablet) ?? Self.defaultsDashboardOrder
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
            Dictionary(uniqueKeysWithValues: dashboardCardSizesPhone.map { ($0.key.rawValue, $0.value.rawValue) }),
            forKey: .dashboardCardSizesPhone
        )
        try container.encode(dashboardOrderPhone, forKey: .dashboardOrderPhone)
        try container.encode(
            Dictionary(uniqueKeysWithValues: dashboardCardSizesTablet.map { ($0.key.rawValue, $0.value.rawValue) }),
            forKey: .dashboardCardSizesTablet
        )
        try container.encode(dashboardOrderTablet, forKey: .dashboardOrderTablet)
    }

    /// Shared by both dashboardCardSizesPhone/Tablet decoding: normalizes the pre-rename
    /// "shopping" key the same way dashboardCards does, and drops any value that isn't a
    /// recognized card or size rather than failing the whole decode.
    private static func decodedDashboardCardSizes(_ raw: [String: String]) -> [DashboardCardId: DashboardCardSize] {
        Dictionary(
            uniqueKeysWithValues: raw.compactMap { key, value in
                let normalizedKey = key == "shopping" ? "groceries" : key
                guard let card = DashboardCardId(rawValue: normalizedKey),
                      let size = DashboardCardSize(rawValue: value) else {
                    return nil
                }
                return (card, size)
            }
        )
    }

    static let sidebarModules: [HubModuleId] = [.notes, .calendar, .groceries, .routines, .chores, .meals, .sleep, .birthdays]
    static let foodModules: [HubModuleId] = [.snacks, .recipes]
    private static let defaultsSidebarOrder: [HubModuleId] = [.notes, .calendar, .groceries, .routines, .chores, .meals, .sleep, .birthdays]
    /// Card size means "how many columns this card spans" — 1 for standard, 2 for
    /// expanded. Schedule is a list of events and Notes hosts a text field, so both
    /// need the extra column. Everything else is a single number or short phrase.
    static let defaultsDashboardCardSizes: [DashboardCardId: DashboardCardSize] = Dictionary(
        uniqueKeysWithValues: DashboardCardId.allCases.map { card in
            switch card {
            case .schedule, .notes: (card, DashboardCardSize.expanded)
            default: (card, DashboardCardSize.standard)
            }
        }
    )

    /// Weather is deliberately absent: it renders in the app header, not as a card.
    /// The enum case still exists so existing stored orders decode, and the views
    /// filter it out. The two double-width cards (Schedule, Notes) sit at the ends so
    /// the single-width cards stay contiguous and pair cleanly into rows on iPhone.
    static let defaultsDashboardOrder: [DashboardCardId] = [.schedule, .routines, .chores, .meals, .snacks, .sleep, .groceries, .birthdays, .notes]

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

    func dashboardOrder(for target: DashboardLayoutTarget) -> [DashboardCardId] {
        switch target {
        case .phone: dashboardOrderPhone
        case .tablet: dashboardOrderTablet
        }
    }

    func dashboardCardSizes(for target: DashboardLayoutTarget) -> [DashboardCardId: DashboardCardSize] {
        switch target {
        case .phone: dashboardCardSizesPhone
        case .tablet: dashboardCardSizesTablet
        }
    }

    func updatingDashboardCardSize(_ card: DashboardCardId, size: DashboardCardSize, for target: DashboardLayoutTarget) -> HubModules {
        var copy = self
        switch target {
        case .phone: copy.dashboardCardSizesPhone[card] = size
        case .tablet: copy.dashboardCardSizesTablet[card] = size
        }
        return copy
    }

    func dashboardCardSize(_ card: DashboardCardId, for target: DashboardLayoutTarget) -> DashboardCardSize {
        dashboardCardSizes(for: target)[card, default: .standard]
    }

    func movingSidebarModule(_ module: HubModuleId, by offset: Int) -> HubModules {
        var copy = self
        copy.sidebarOrder = Self.moving(module, in: sidebarOrder, by: offset)
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
        case .birthdays: CelebrationNaming.current
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
