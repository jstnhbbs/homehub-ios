import Foundation

/// One card to place on the Today grid: how many columns and rows of cells it covers.
struct DashboardGridItem: Equatable, Sendable {
    var card: DashboardCardId
    var columns: Int
    var rows: Int
}

/// Where a card landed: its top-left cell and how many cells it covers.
struct DashboardGridPlacement: Equatable, Sendable, Identifiable {
    var card: DashboardCardId
    var column: Int
    var row: Int
    var columns: Int
    var rows: Int

    var id: DashboardCardId { card }
}

/// Puts cards of different sizes (1 x 1, 2 x 1, 2 x 2 cells) on a grid with a fixed number of columns.
///
/// Each card, in the order the person arranged them, takes the first spot (reading left to right, top
/// to bottom) where it fits, so a small card slides up beside a large one instead of leaving a hole,
/// and the order on screen stays close to the order in the list. A card wider than the grid is made
/// as wide as the grid.
enum DashboardGridPacker {
    struct Result: Equatable, Sendable {
        var placements: [DashboardGridPlacement]
        var rowCount: Int
    }

    static func pack(_ items: [DashboardGridItem], columnCount: Int) -> Result {
        let columnCount = max(1, columnCount)
        var occupied: [[Bool]] = []
        var placements: [DashboardGridPlacement] = []

        func ensureRows(_ count: Int) {
            while occupied.count < count {
                occupied.append(Array(repeating: false, count: columnCount))
            }
        }

        func fits(column: Int, row: Int, columns: Int, rows: Int) -> Bool {
            guard column + columns <= columnCount else { return false }
            for r in row..<(row + rows) where r < occupied.count {
                for c in column..<(column + columns) where occupied[r][c] {
                    return false
                }
            }
            return true
        }

        for item in items {
            let columns = max(1, min(item.columns, columnCount))
            let rows = max(1, item.rows)
            var row = 0
            var placed = false
            while !placed {
                for column in 0...(columnCount - columns) where fits(column: column, row: row, columns: columns, rows: rows) {
                    ensureRows(row + rows)
                    for r in row..<(row + rows) {
                        for c in column..<(column + columns) {
                            occupied[r][c] = true
                        }
                    }
                    placements.append(DashboardGridPlacement(card: item.card, column: column, row: row, columns: columns, rows: rows))
                    placed = true
                    break
                }
                row += 1
            }
        }

        return Result(placements: placements, rowCount: occupied.count)
    }

    /// The number of grid columns that gives the cards the best proportions on a page of `size`, up to
    /// `widthCap` (what the width allows). Each count from the narrowest the cards need up to the cap
    /// is packed, and the one whose cells come closest to a comfortable landscape shape wins; a tie
    /// goes to more columns. With no sensible height (a scrolling page) the cap is used.
    static func columnCount(
        widthCap: Int,
        items: [DashboardGridItem],
        size: CGSize,
        spacing: CGFloat,
        targetAspect: Double = 1.7
    ) -> Int {
        let cap = max(1, widthCap)
        guard cap > 1, !items.isEmpty else { return 1 }
        // Cards sit side by side whenever there is more than one (or any is wider than a cell).
        let narrowest = items.count > 1 || (items.map(\.columns).max() ?? 1) > 1 ? 2 : 1
        guard narrowest < cap, size.width > 0, size.height > 0 else { return cap }

        var best = cap
        var bestScore = Double.infinity
        for columns in stride(from: cap, through: narrowest, by: -1) {
            let rows = max(1, pack(items, columnCount: columns).rowCount)
            let cellWidth = (Double(size.width) - Double(columns - 1) * Double(spacing)) / Double(columns)
            let cellHeight = (Double(size.height) - Double(rows - 1) * Double(spacing)) / Double(rows)
            guard cellWidth > 0, cellHeight > 0 else { continue }
            let score = abs(log(cellWidth / cellHeight / targetAspect))
            if score < bestScore - 0.0001 {
                bestScore = score
                best = columns
            }
        }
        return best
    }
}
