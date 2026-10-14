import Foundation
import CoreGraphics

/// Fills columns of a Large card with a list that mixes headings and rows (aisles and groceries, months and
/// celebrations): top to bottom, then left to right. A heading is only placed if the row after it fits
/// too, so one is never left alone at the bottom of a column. Whatever does not fit is counted (headings are
/// not counted), and a line for "+N more" is kept free when something is left out.
enum ColumnFit {
    struct Result<Entry> {
        var columns: [[Entry]]
        var hiddenItems: Int
    }

    static func fit<Entry>(
        _ entries: [Entry],
        isItem: (Entry) -> Bool,
        columnCount: Int,
        itemHeight: CGFloat,
        headerHeight: CGFloat,
        spacing: CGFloat,
        footerHeight: CGFloat,
        availableHeight: CGFloat
    ) -> Result<Entry> {
        func place(height: CGFloat) -> Result<Entry> {
            var columns: [[Entry]] = Array(repeating: [], count: max(1, columnCount))
            var used: [CGFloat] = Array(repeating: 0, count: columns.count)
            var column = 0
            var index = 0
            while index < entries.count {
                let entry = entries[index]
                let entryIsItem = isItem(entry)
                var needed = entryIsItem ? itemHeight : headerHeight
                if !entryIsItem, index + 1 < entries.count { needed += spacing + itemHeight }
                let gap = columns[column].isEmpty ? 0 : spacing
                if used[column] + gap + needed <= height {
                    columns[column].append(entry)
                    used[column] += gap + (entryIsItem ? itemHeight : headerHeight)
                    index += 1
                } else if column + 1 < columns.count {
                    column += 1
                } else {
                    break
                }
            }
            return Result(columns: columns, hiddenItems: entries[index...].filter(isItem).count)
        }
        let full = place(height: availableHeight)
        return full.hiddenItems == 0 ? full : place(height: max(0, availableHeight - footerHeight))
    }
}
