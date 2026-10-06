import SwiftUI

// Building blocks shared by every card on the iPad/Mac Today grid, so the cards read as one
// family: the same row, the same "+N more" footer, and the same whole-rows-only fitting.

/// The one row style the dashboard cards share: a marker on the left, a title with an optional
/// subtitle, and an optional control on the right. Every row is the same height, so a card can
/// tell how many fit without estimating.
private struct DashboardRowCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by a card that has squeezed its rows to the compact height to reveal one more row.
    var dashboardRowIsCompact: Bool {
        get { self[DashboardRowCompactKey.self] }
        set { self[DashboardRowCompactKey.self] = newValue }
    }
}

struct DashboardRow<Leading: View, Trailing: View>: View {
    /// Matches the Meals tiles: room for a title that wraps to two lines, or a title with a line
    /// under it.
    static var height: CGFloat { DashboardMetrics.scaled(60) }

    /// The tighter height a card may use when that lets another row show. A title that wraps to two
    /// lines still fits; a title with a subtitle drops to one line.
    static var compactHeight: CGFloat { DashboardMetrics.scaled(48) }

    /// The narrowest a row can be and still read: a marker, then room for a short title that wraps
    /// to two lines. Every card uses this to decide how many columns of rows fit, so they all make
    /// the same call.
    static var minimumWidth: CGFloat { DashboardMetrics.scaled(124) }

    /// A row whose subtitle is a sentence ("No sleep logged today") needs more width than that.
    static var minimumWidthWithStatus: CGFloat { DashboardMetrics.scaled(190) }

    let title: String
    var subtitle: String?
    var isDone = false
    /// Colours the row to match a person (a child's routine) or to call attention to it (a
    /// birthday today). Nil is the standard quiet tile.
    var tint: Color?
    var tintStrength = 0.1
    var outline: Color?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.dashboardRowIsCompact) private var isCompact

    private var rowHeight: CGFloat { isCompact ? Self.compactHeight : Self.height }

    var body: some View {
        HStack(spacing: 8) {
            leading()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? HubTheme.muted : .primary)
                    .strikethrough(isDone, color: HubTheme.muted)
                    .lineLimit(isCompact && subtitle != nil ? 1 : 2)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .background(tint.map { $0.opacity(tintStrength) } ?? HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(outline ?? tint?.opacity(0.2) ?? .clear, lineWidth: outline == nil ? 1 : 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The checkbox marker for rows that can be ticked off.
struct DashboardCheckMarker: View {
    let isChecked: Bool

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.bold))
            .foregroundStyle(isChecked ? HubTheme.sage : HubTheme.muted)
    }
}

/// The "+N more" line under a card that has more items than fit. Tapping it opens the full list.
struct DashboardMoreFooter: View {
    static var height: CGFloat { DashboardMetrics.scaled(22, .caption1) }

    let count: Int
    /// Extra text after the count, e.g. "25 to buy", so a card's summary shares this one line
    /// instead of costing a second.
    var suffix: String?
    let action: () -> Void

    private var text: String {
        suffix.map { "+\(count) more · \($0)" } ?? "+\(count) more"
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
                .frame(maxWidth: .infinity, minHeight: Self.height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text). Open the full list.")
    }
}

extension View {
    /// Fallback for a card so short that even one row leaves no room for the "+N more" line: a small
    /// chip in the corner instead, so the count is never silently clipped.
    func dashboardMoreChip(hidden: Int, footerFits: Bool, suffix: String? = nil, action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            if hidden > 0 && !footerFits {
                Button(action: action) {
                    Text(suffix.map { "+\(hidden) more · \($0)" } ?? "+\(hidden) more")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(HubTheme.tile)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(HubTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(hidden) more. Open the full list.")
            }
        }
    }
}

/// Lays tiles out row by row in as many columns as fit, and shows only whole rows: whatever does
/// not fit is summarised as "+N more" instead of being sliced in half or hidden behind a scroll
/// nobody uses on a wall dashboard. Every tile in a row gets that row's height, so rows stay even.
///
/// `itemHeight` must be at least what the tile really needs at the given column width; a tile is
/// clipped to its row rather than allowed to grow.
struct WholeRowsGrid<Item: Identifiable, Tile: View>: View {
    let items: [Item]
    let minimumColumnWidth: CGFloat
    var maxColumns = 4
    var spacing: CGFloat = 8
    let itemHeight: (Item, CGFloat) -> CGFloat
    let onMore: () -> Void
    /// Optional line shown under the rows, only when there is room to spare and nothing is hidden.
    var spareHint: String?
    /// Joined onto the "+N more" line when rows are hidden.
    var moreSuffix: String?
    /// Centre and enlarge the line, for a card's summary rather than a hint.
    var centersHint = false
    /// Let the rows tighten to `DashboardRow.compactHeight` when that shows more of them. Only for
    /// cards whose tiles are `DashboardRow`s.
    var allowsCompactRows = false
    @ViewBuilder let tile: (Item, CGFloat) -> Tile

    private var hintHeight: CGFloat { DashboardMetrics.scaled(30, .caption1) }
    /// The footer sits against the bottom of the card, partly in its padding, so it costs the rows
    /// less space and the card does not look like it has an empty strip under it.
    private let footerOverlap: CGFloat = 8
    private let footerGap: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let columns = DashboardRowHelpers.columnCount(
                availableWidth: geo.size.width,
                minimumColumnWidth: minimumColumnWidth,
                spacing: spacing,
                maxColumns: maxColumns
            )
            let columnWidth = (geo.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let comfortableHeights = items.map { itemHeight($0, columnWidth) }
            let comfortableFit = fit(comfortableHeights, columns: columns, height: geo.size.height)
            let compactHeights = items.map { _ in DashboardRow<EmptyView, EmptyView>.compactHeight }
            let compactFit = fit(compactHeights, columns: columns, height: geo.size.height)
            // Use the tighter rows only when they actually reveal another one.
            let useCompact = allowsCompactRows && compactFit.shown > comfortableFit.shown
            let heights = useCompact ? compactHeights : comfortableHeights
            let fit = useCompact ? compactFit : comfortableFit
            let shownHeights = Array(heights.prefix(fit.shown))
            let usedHeight = DashboardRowHelpers.rowsHeight(itemHeights: shownHeights, columns: columns, spacing: spacing)
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<rowCount(shown: fit.shown, columns: columns), id: \.self) { row in
                    let start = row * columns
                    let end = min(start + columns, fit.shown)
                    let rowHeight = heights[start..<end].max() ?? 0
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(items[start..<end])) { item in
                            tile(item, columnWidth)
                                .environment(\.dashboardRowIsCompact, useCompact)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight, alignment: .top)
                        }
                        ForEach(0..<(columns - (end - start)), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: centersHint ? .bottom : .bottomLeading) {
                if fit.hidden > 0 && fit.footerFits {
                    DashboardMoreFooter(count: fit.hidden, suffix: moreSuffix, action: onMore)
                        .offset(y: footerOverlap)
                } else if let spareHint, geo.size.height - usedHeight >= hintHeight {
                    Text(spareHint)
                        .font(centersHint ? .caption.weight(.bold) : .caption2.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(2)
                        .frame(maxWidth: centersHint ? .infinity : nil)
                        .multilineTextAlignment(centersHint ? .center : .leading)
                        .offset(y: footerOverlap)
                }
            }
            .dashboardMoreChip(hidden: fit.hidden, footerFits: fit.footerFits, suffix: moreSuffix, action: onMore)
        }
    }

    private func fit(_ heights: [CGFloat], columns: Int, height: CGFloat) -> (shown: Int, hidden: Int, footerFits: Bool) {
        DashboardRowHelpers.fitWholeRows(
            itemHeights: heights,
            columns: columns,
            spacing: spacing,
            availableHeight: height,
            footerHeight: DashboardMoreFooter.height - footerOverlap,
            footerGap: footerGap
        )
    }

    private func rowCount(shown: Int, columns: Int) -> Int {
        (shown + columns - 1) / columns
    }
}

