import Foundation

/// A Today layout someone has chosen to come back to: which cards are on, their order and their sizes,
/// for one kind of device (iPhone, or iPad and Mac, which are arranged separately).
///
/// "Reset layout" goes back to the app's own arrangement. This is the household's own: set up the
/// cards the way the family likes, save it, and restore it whenever the cards get moved around too
/// much. It is kept on the device, per signed-in person and per kind of device.
struct TodayLayoutDefault: Codable, Equatable, Sendable {
    /// Stored with plain strings as keys so the saved copy doesn't depend on how Swift encodes
    /// dictionaries keyed by an enum.
    var order: [String]
    var sizes: [String: String]
    var enabled: [String: Bool]

    /// What the layout looks like now, for `target`.
    static func capture(from modules: HubModules, target: DashboardLayoutTarget) -> TodayLayoutDefault {
        TodayLayoutDefault(
            order: modules.dashboardOrder(for: target).map(\.rawValue),
            sizes: Dictionary(uniqueKeysWithValues: modules.dashboardCardSizes(for: target).map { ($0.key.rawValue, $0.value.rawValue) }),
            enabled: Dictionary(uniqueKeysWithValues: modules.dashboardCards.map { ($0.key.rawValue, $0.value) })
        )
    }

    /// `modules` with this layout put back for `target`. Cards added to the app since it was saved
    /// are kept (at the end, in the order they have now) rather than lost; cards that no longer exist
    /// are dropped. Nothing outside the Today cards (navigation, Food tabs, the other kind of device's
    /// order and sizes) changes. Which cards are turned on is shared by every device, so restoring it
    /// changes that for both.
    func applied(to modules: HubModules, target: DashboardLayoutTarget) -> HubModules {
        var next = modules

        var restoredOrder: [DashboardCardId] = []
        for raw in order {
            if let card = DashboardCardId(rawValue: raw), !restoredOrder.contains(card) {
                restoredOrder.append(card)
            }
        }
        for card in modules.dashboardOrder(for: target) where !restoredOrder.contains(card) {
            restoredOrder.append(card)
        }
        for card in DashboardCardId.allCases where !restoredOrder.contains(card) {
            restoredOrder.append(card)
        }

        var restoredSizes = modules.dashboardCardSizes(for: target)
        for (raw, size) in sizes {
            if let card = DashboardCardId(rawValue: raw), let value = DashboardCardSize(rawValue: size) {
                restoredSizes[card] = value
            }
        }

        for (raw, on) in enabled {
            if let card = DashboardCardId(rawValue: raw) {
                next.dashboardCards[card] = on
            }
        }

        switch target {
        case .phone:
            next.dashboardOrderPhone = restoredOrder
            next.dashboardCardSizesPhone = restoredSizes
        case .tablet:
            next.dashboardOrderTablet = restoredOrder
            next.dashboardCardSizesTablet = restoredSizes
        }
        return next
    }

    /// Whether `modules` already looks exactly like this for `target`, so there is nothing to restore.
    func matches(_ modules: HubModules, target: DashboardLayoutTarget) -> Bool {
        applied(to: modules, target: target) == modules
    }
}

/// Keeps one saved layout per signed-in person and kind of device.
struct TodayLayoutDefaultStore {
    var defaults: UserDefaults = .standard

    private func key(userId: String, target: DashboardLayoutTarget) -> String {
        "homehub.todayLayoutDefault.\(userId).\(target.rawValue)"
    }

    func load(userId: String, target: DashboardLayoutTarget) -> TodayLayoutDefault? {
        guard let data = defaults.data(forKey: key(userId: userId, target: target)) else { return nil }
        return try? JSONDecoder().decode(TodayLayoutDefault.self, from: data)
    }

    func save(_ layout: TodayLayoutDefault, userId: String, target: DashboardLayoutTarget) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        defaults.set(data, forKey: key(userId: userId, target: target))
    }

    func clear(userId: String, target: DashboardLayoutTarget) {
        defaults.removeObject(forKey: key(userId: userId, target: target))
    }
}
