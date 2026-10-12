import Foundation
import CoreGraphics

/// One line in the Large Groceries card's columns: an aisle's heading or an item.
enum GroceryEntry: Identifiable {
    case header(String)
    case item(GroceryItem)

    var id: String {
        switch self {
        case .header(let name): "header-\(name)"
        case .item(let item): item.id
        }
    }

    var isItem: Bool {
        if case .item = self { return true }
        return false
    }
}

/// What the Groceries card says, and how its Large layout fills its columns.
struct GroceryCardSummary {
    /// Items still to buy, in the order they should read.
    let items: [GroceryItem]
    /// Items checked off lately.
    let checked: [GroceryItem]
    /// True for the household's own list, whose items have real aisles; false for an Apple Reminders list,
    /// where every item's "category" is just the list's name.
    let isServerBacked: Bool

    var count: Int { items.count }

    /// The big words on a Small card.
    var headline: String { count == 0 ? "All set" : "\(count)" }
    var caption: String { count == 0 ? "Nothing to buy" : (count == 1 ? "item to buy" : "items to buy") }

    /// The one line above a Medium or Large card's rows.
    var line: String { count == 0 ? "Nothing to buy" : "\(count) to buy" }

    /// Whether the list has more than one aisle, so headings help.
    var isGrouped: Bool {
        isServerBacked && Set(items.map(\.category)).count > 1
    }

    /// The list as the Large card reads it: under an aisle heading each when the aisles differ, then (if
    /// there is any) a "Checked off" heading with what was just checked. Only items count as items.
    var entries: [GroceryEntry] {
        var result: [GroceryEntry] = []
        if isGrouped {
            var order: [String] = []
            for item in items where !order.contains(item.category) { order.append(item.category) }
            for aisle in order {
                result.append(.header(aisle))
                result.append(contentsOf: items.filter { $0.category == aisle }.map(GroceryEntry.item))
            }
        } else {
            result.append(contentsOf: items.map(GroceryEntry.item))
        }
        if !checked.isEmpty {
            result.append(.header("Checked off"))
            result.append(contentsOf: checked.prefix(12).map(GroceryEntry.item))
        }
        return result
    }

    struct Layout {
        var columns: [[GroceryEntry]]
        /// Items that did not fit (headings are not counted).
        var hiddenItems: Int
    }

    /// Fills `columnCount` columns of `availableHeight`; see `ColumnFit`.
    static func fit(
        _ entries: [GroceryEntry],
        columnCount: Int,
        itemHeight: CGFloat,
        headerHeight: CGFloat,
        spacing: CGFloat,
        footerHeight: CGFloat,
        availableHeight: CGFloat
    ) -> Layout {
        let result = ColumnFit.fit(
            entries, isItem: { $0.isItem }, columnCount: columnCount, itemHeight: itemHeight,
            headerHeight: headerHeight, spacing: spacing, footerHeight: footerHeight, availableHeight: availableHeight
        )
        return Layout(columns: result.columns, hiddenItems: result.hiddenItems)
    }
}
