import Foundation

/// The rules behind rearranging the Today cards on the page itself (the wiggle mode): which card
/// goes where when one is dragged over another, how the new order is saved without disturbing cards
/// that are turned off, and which cards can still be added back.
enum TodayLayoutEditing {
    /// `order` with `card` moved to the place `target` holds, so the dragged card takes its spot and the
    /// cards in between shift by one. Unchanged if either card is missing or they are the same.
    static func moving(_ card: DashboardCardId, ontoPositionOf target: DashboardCardId, in order: [DashboardCardId]) -> [DashboardCardId] {
        guard card != target,
              let from = order.firstIndex(of: card),
              let to = order.firstIndex(of: target) else { return order }
        var next = order
        next.remove(at: from)
        next.insert(card, at: to)
        return next
    }

    /// How many half-width cards sit alone in their row, with an empty half beside them, when `order` is laid
    /// out on the iPhone: half-width cards pair up in order, and a full-width card ends the row it arrives in,
    /// so a half-width card waiting for a partner is left alone by it. Counts the one at the very end too.
    static func lonelyHalfWidthCount(in order: [DashboardCardId], isHalfWidth: (DashboardCardId) -> Bool) -> Int {
        var lonely = 0
        var waiting = false
        for card in order {
            if isHalfWidth(card) {
                waiting.toggle()
            } else if waiting {
                lonely += 1
                waiting = false
            }
        }
        return waiting ? lonely + 1 : lonely
    }

    /// Whether dragging `card` so the order becomes `proposed` is allowed on the iPhone. A full-width card may not
    /// be dropped between two half-width cards that share a row, which would leave both of them alone with an empty
    /// half beside each; it can go before the pair or after it. Half-width cards can go anywhere.
    static func allowsPhoneMove(
        of card: DashboardCardId,
        from current: [DashboardCardId],
        to proposed: [DashboardCardId],
        isHalfWidth: (DashboardCardId) -> Bool
    ) -> Bool {
        guard !isHalfWidth(card) else { return true }
        return lonelyHalfWidthCount(in: proposed, isHalfWidth: isHalfWidth)
            <= lonelyHalfWidthCount(in: current, isHalfWidth: isHalfWidth)
    }

    /// `card` moved `offset` places (negative is earlier), staying inside the list.
    static func moving(_ card: DashboardCardId, by offset: Int, in order: [DashboardCardId]) -> [DashboardCardId] {
        guard let from = order.firstIndex(of: card) else { return order }
        let to = max(0, min(order.count - 1, from + offset))
        guard to != from else { return order }
        var next = order
        next.remove(at: from)
        next.insert(card, at: to)
        return next
    }

    /// The stored order for a device after the visible cards were rearranged. Cards that are turned
    /// off (and Weather, which lives in the header) keep their places; the visible cards fill the
    /// remaining places in their new order. Any card missing from `stored` is added at the end.
    static func storedOrder(_ stored: [DashboardCardId], afterArranging visible: [DashboardCardId]) -> [DashboardCardId] {
        let visibleSet = Set(visible)
        var queue = visible[...]
        var result: [DashboardCardId] = []
        for card in stored {
            if visibleSet.contains(card) {
                if let next = queue.popFirst() { result.append(next) }
            } else {
                result.append(card)
            }
        }
        result.append(contentsOf: queue.filter { !result.contains($0) })
        for card in DashboardCardId.allCases where !result.contains(card) {
            result.append(card)
        }
        return result
    }

    /// Cards that can be switched back on: not shown now, and whose own module is still on (a card
    /// for a module that is off can't show anything). Weather is header chrome, never a card.
    static func addableCards(in modules: HubModules) -> [DashboardCardId] {
        DashboardCardId.allCases.filter { card in
            guard card != .weather else { return false }
            if let module = card.requiredModule, !modules.isEnabled(module) { return false }
            return !modules.dashboardCards[card, default: true]
        }
    }
}

extension HubModules {
    /// These modules with the Today cards for `target` arranged as `visible`.
    func arrangingDashboardCards(_ visible: [DashboardCardId], for target: DashboardLayoutTarget) -> HubModules {
        var next = self
        let order = TodayLayoutEditing.storedOrder(dashboardOrder(for: target), afterArranging: visible)
        switch target {
        case .phone: next.dashboardOrderPhone = order
        case .tablet: next.dashboardOrderTablet = order
        }
        return next
    }
}
