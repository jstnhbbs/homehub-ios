import Foundation

enum GroceryHelpers {
    static func groupedItems(_ items: [GroceryItem]) -> [(category: String, items: [GroceryItem])] {
        let orderedCategories = Array(NSOrderedSet(array: items.map(\.category))) as? [String] ?? []
        return orderedCategories.map { category in
            (category, items.filter { $0.category == category })
        }
    }

    static func sortedItems(_ items: [GroceryItem]) -> [GroceryItem] {
        items.sorted { lhs, rhs in
            if lhs.checked != rhs.checked { return !lhs.checked }
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        }
    }

    static func displayTitle(_ item: GroceryItem) -> String {
        guard let quantity = item.quantity, !quantity.isEmpty else {
            return item.title
        }
        return "\(quantity) \(item.title)"
    }
}
