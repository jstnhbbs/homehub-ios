import Foundation

/// Only edited fields travel to the server; untouched phone/tablet preferences belong to the other device.
struct HubModulesPatch: Encodable, Sendable {
    var toggles: [HubModuleId: Bool] = [:]
    var cards: [DashboardCardId: Bool] = [:]
    var phoneSizes: [DashboardCardId: DashboardCardSize] = [:]
    var tabletSizes: [DashboardCardId: DashboardCardSize] = [:]
    var sidebarOrder: [HubModuleId]?
    var phoneOrder: [DashboardCardId]?
    var tabletOrder: [DashboardCardId]?

    init() {}

    init(from previous: HubModules, to next: HubModules) {
        for module in HubModuleId.allCases where previous.isEnabled(module) != next.isEnabled(module) {
            toggles[module] = next.isEnabled(module)
        }
        for card in DashboardCardId.allCases {
            if previous.dashboardCards[card] != next.dashboardCards[card] { cards[card] = next.dashboardCards[card] }
            if previous.dashboardCardSizesPhone[card] != next.dashboardCardSizesPhone[card] { phoneSizes[card] = next.dashboardCardSizesPhone[card] }
            if previous.dashboardCardSizesTablet[card] != next.dashboardCardSizesTablet[card] { tabletSizes[card] = next.dashboardCardSizesTablet[card] }
        }
        if previous.sidebarOrder != next.sidebarOrder { sidebarOrder = next.sidebarOrder }
        if previous.dashboardOrderPhone != next.dashboardOrderPhone { phoneOrder = next.dashboardOrderPhone }
        if previous.dashboardOrderTablet != next.dashboardOrderTablet { tabletOrder = next.dashboardOrderTablet }
    }

    var isEmpty: Bool {
        toggles.isEmpty && cards.isEmpty && phoneSizes.isEmpty && tabletSizes.isEmpty
            && sidebarOrder == nil && phoneOrder == nil && tabletOrder == nil
    }

    func merging(_ newer: HubModulesPatch) -> HubModulesPatch {
        var copy = self
        copy.toggles.merge(newer.toggles) { _, new in new }
        copy.cards.merge(newer.cards) { _, new in new }
        copy.phoneSizes.merge(newer.phoneSizes) { _, new in new }
        copy.tabletSizes.merge(newer.tabletSizes) { _, new in new }
        copy.sidebarOrder = newer.sidebarOrder ?? sidebarOrder
        copy.phoneOrder = newer.phoneOrder ?? phoneOrder
        copy.tabletOrder = newer.tabletOrder ?? tabletOrder
        return copy
    }

    func applying(to modules: HubModules) -> HubModules {
        var copy = modules
        for (module, enabled) in toggles { copy = copy.updating(module, enabled: enabled) }
        copy.dashboardCards.merge(cards) { _, new in new }
        copy.dashboardCardSizesPhone.merge(phoneSizes) { _, new in new }
        copy.dashboardCardSizesTablet.merge(tabletSizes) { _, new in new }
        if let sidebarOrder { copy.sidebarOrder = sidebarOrder }
        if let phoneOrder { copy.dashboardOrderPhone = phoneOrder }
        if let tabletOrder { copy.dashboardOrderTablet = tabletOrder }
        return copy
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for (module, value) in toggles { try container.encode(value, forKey: Key(module.rawValue)) }
        if !cards.isEmpty {
            try container.encode(Dictionary(uniqueKeysWithValues: cards.map { ($0.key.rawValue, $0.value) }), forKey: Key("dashboardCards"))
        }
        if !phoneSizes.isEmpty {
            try container.encode(Dictionary(uniqueKeysWithValues: phoneSizes.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: Key("dashboardCardSizesPhone"))
        }
        if !tabletSizes.isEmpty {
            try container.encode(Dictionary(uniqueKeysWithValues: tabletSizes.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: Key("dashboardCardSizesTablet"))
        }
        try container.encodeIfPresent(sidebarOrder, forKey: Key("sidebarOrder"))
        try container.encodeIfPresent(phoneOrder, forKey: Key("dashboardOrderPhone"))
        try container.encodeIfPresent(tabletOrder, forKey: Key("dashboardOrderTablet"))
    }
}
