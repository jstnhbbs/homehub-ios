import CoreGraphics
import Foundation

/// Small rules for when a dashboard row's second line is worth showing. In both cases the
/// underlying value can be the *same string repeated on every row* — a native reminder's
/// "category" is really just the name of the Reminders list it lives in, and a schedule row's
/// calendar name is the same for every event when there is only one calendar. Repeating a
/// constant on every row adds no information once you have seen it once, at the cost of a whole
/// line per item.
enum DashboardRowHelpers {
    /// What to show under a grocery item's title.
    ///
    /// A real quantity (from a server-tracked item, or one a person eventually types into the
    /// reminder) always wins. Failing that, `category` is only shown when the item is
    /// server-tracked, where it is a genuine per-item categorization ("Produce", "Dairy", ...).
    /// A native-Reminders item's `category` is the Reminders *list's own name* — identical for
    /// every item in the list — so there is nothing useful to show.
    static func grocerySubtitle(quantity: String?, category: String, isServerBacked: Bool) -> String? {
        if let quantity, !quantity.trimmingCharacters(in: .whitespaces).isEmpty {
            return quantity
        }
        return isServerBacked ? category : nil
    }

    /// Whether a chore row should say who it is for. When every chore on the card is for the same
    /// person ("Anyone" on all of them, or one child's whole list) the line is the same string on
    /// every row, and dropping it lets a row be about a third shorter so more of them fit.
    static func showsAssignee(_ assigneeNames: [String]) -> Bool {
        Set(assigneeNames).count > 1
    }

    /// Whether a schedule row should append its calendar's name. Worth it once the visible
    /// events come from more than one calendar; with a single calendar it is the same string
    /// on every row.
    static func showsCalendarName(_ calendarNames: [String?]) -> Bool {
        Set(calendarNames.compactMap { $0 }).count > 1
    }

    /// How many same-height rows fit in `availableHeight` without needing to scroll, so a card
    /// given more room (a wider window, or fewer other cards sharing the grid) genuinely shows
    /// more — rather than every card showing the same fixed count regardless of size.
    /// `columns` lets this cover a 2-column grid (groceries, snacks) as well as a plain list.
    ///
    /// Always fits at least one row: a `GeometryReader` can briefly report zero height before its
    /// real layout pass settles, and showing nothing for that one frame would flash the card's
    /// empty state even though it has items.
    static func visibleRowCount(availableHeight: CGFloat, rowHeight: CGFloat, spacing: CGFloat, columns: Int, total: Int) -> Int {
        guard rowHeight > 0, columns > 0 else { return total }
        let rows = max(1, Int(floor((availableHeight + spacing) / (rowHeight + spacing))))
        return min(total, rows * columns)
    }

    /// How many columns of at least `minimumColumnWidth` fit in `availableWidth`, between one and
    /// `maxColumns`. A half-width card on a 10.5" iPad is under 300pt wide, so a fixed two-column
    /// grid squeezes every tile to about 130pt and turns titles into "Go...".
    static func columnCount(availableWidth: CGFloat, minimumColumnWidth: CGFloat, spacing: CGFloat, maxColumns: Int = 2) -> Int {
        guard minimumColumnWidth > 0, availableWidth > 0 else { return 1 }
        let fits = Int(floor((availableWidth + spacing) / (minimumColumnWidth + spacing)))
        return min(max(1, maxColumns), max(1, fits))
    }

    /// Fits items of differing heights, laid out row by row in `columns` columns, into
    /// `availableHeight` without ever showing a partial row. A row is as tall as its tallest item.
    ///
    /// When everything fits, nothing is hidden. Otherwise the space for a one-line "+N more"
    /// footer (`footerHeight` plus one `spacing`) is taken off first, so the footer never covers a
    /// row. Always shows at least one row: a measured height can briefly be zero before layout
    /// settles, and an empty card for that frame would flash the empty state. `footerFits` is false
    /// only in that forced-single-row case, when the footer line has nowhere to go.
    static func fitWholeRows(
        itemHeights: [CGFloat],
        columns: Int,
        spacing: CGFloat,
        availableHeight: CGFloat,
        footerHeight: CGFloat,
        footerGap: CGFloat? = nil
    ) -> (shown: Int, hidden: Int, footerFits: Bool) {
        let total = itemHeights.count
        guard total > 0 else { return (0, 0, true) }
        let columnCount = max(1, columns)

        func shown(fittingIn height: CGFloat) -> Int {
            var used: CGFloat = 0
            var rowsPlaced = 0
            var index = 0
            while index < total {
                let end = min(index + columnCount, total)
                let rowHeight = itemHeights[index..<end].max() ?? 0
                let needed = used + (rowsPlaced == 0 ? 0 : spacing) + rowHeight
                if rowsPlaced > 0 && needed > height { break }
                used = needed
                rowsPlaced += 1
                index = end
            }
            return index
        }

        // The footer normally sits one row-gap under the rows; a caller that pins it to the bottom
        // edge passes a smaller gap.
        let gap = footerGap ?? spacing
        let everything = shown(fittingIn: availableHeight)
        if everything >= total { return (total, 0, true) }
        let withFooter = shown(fittingIn: availableHeight - footerHeight - gap)
        // Even a single forced row can leave no room for the footer line; the caller then shows
        // the count another way rather than letting it be clipped.
        let used = rowsHeight(itemHeights: Array(itemHeights.prefix(withFooter)), columns: columnCount, spacing: spacing)
        return (withFooter, total - withFooter, used + gap + footerHeight <= availableHeight)
    }

    /// Rough number of lines `characterCount` characters wrap to in `availableWidth`, between one
    /// and `maxLines`. Deliberately generous (callers pass a wide `averageCharacterWidth`), because
    /// word wrapping breaks earlier than a pure character count, and a tile sized one line short
    /// would clip its text.
    static func estimatedLineCount(characterCount: Int, availableWidth: CGFloat, averageCharacterWidth: CGFloat, maxLines: Int) -> Int {
        let limit = max(1, maxLines)
        guard availableWidth > 0, averageCharacterWidth > 0 else { return limit }
        let perLine = max(1, Int(floor(availableWidth / averageCharacterWidth)))
        let lines = Int(ceil(Double(max(characterCount, 1)) / Double(perLine)))
        return min(limit, max(1, lines))
    }

    /// Total height of the given items laid out row by row, a row being as tall as its tallest item.
    static func rowsHeight(itemHeights: [CGFloat], columns: Int, spacing: CGFloat) -> CGFloat {
        let columnCount = max(1, columns)
        var total: CGFloat = 0
        var index = 0
        while index < itemHeights.count {
            let end = min(index + columnCount, itemHeights.count)
            total += (index == 0 ? 0 : spacing) + (itemHeights[index..<end].max() ?? 0)
            index = end
        }
        return total
    }

    /// How many lines `count` equal-sized chips wrap to in `availableWidth`.
    static func chipRowCount(count: Int, availableWidth: CGFloat, chipSize: CGFloat, spacing: CGFloat) -> Int {
        guard count > 0 else { return 0 }
        guard availableWidth > 0, chipSize > 0 else { return count }
        let perRow = max(1, Int(floor((availableWidth + spacing) / (chipSize + spacing))))
        return Int(ceil(Double(count) / Double(perRow)))
    }

    /// Whether every item fits in `availableHeight` as it is, with no forced row. `fitWholeRows`
    /// always keeps at least one row, so on its own it cannot tell a short card whose single row
    /// overflows from one that really fits.
    static func allFit(itemHeights: [CGFloat], columns: Int, spacing: CGFloat, availableHeight: CGFloat) -> Bool {
        rowsHeight(itemHeights: itemHeights, columns: columns, spacing: spacing) <= availableHeight
    }
}
