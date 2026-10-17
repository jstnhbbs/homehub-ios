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
    /// What VoiceOver says for the subtitle when the visible words are abbreviated to fit.
    var subtitleSpokenText: String?
    /// A small dot in this color before the subtitle, when the subtitle starts with a person's name.
    var subtitlePersonColor: Color?
    /// False for a row that has nothing worth a marker, so its text gets the room.
    var showsLeading = true
    /// How wide the marker's column is. A small dot needs far less than a checkbox, and a narrow column
    /// gives the text the difference.
    var leadingWidth: CGFloat = 28
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

    /// The subtitle, with a person's colored dot in front when there is one. It is one `Text`, so it
    /// truncates like any other line.
    private func subtitleText(_ subtitle: String) -> Text {
        guard let personColor = subtitlePersonColor else { return Text(subtitle) }
        return Text(Image(systemName: "circle.fill")).font(.system(size: 7)).foregroundStyle(personColor).baselineOffset(1)
            + Text(" \(subtitle)")
    }

    var body: some View {
        HStack(spacing: 8) {
            if showsLeading {
                leading()
                    .frame(width: leadingWidth, height: 28)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? HubTheme.muted : .primary)
                    .strikethrough(isDone, color: HubTheme.muted)
                    // One line when there is a subtitle under it, on every row of every card (a title that wrapped to
                    // two with a subtitle under it filled a row from edge to edge); two when it stands alone.
                    .lineLimit(subtitle != nil ? 1 : 2)
                    .minimumScaleFactor(subtitle != nil ? 0.85 : 1)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    subtitleText(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                        .accessibilityLabel(subtitleSpokenText ?? subtitle)
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
            .foregroundStyle(isChecked ? HubTheme.accentText : HubTheme.muted)
            // The row's button says whether it is done; the picture would only be read aloud as
            // "checkmark circle fill".
            .accessibilityHidden(true)
    }
}

/// How many of a card's items do not fit, reported up to the card's frame, which shows it as one "+N more"
/// pill in the header row (beside the chevron). Every card and size does it the same way, so the count is
/// always in the same place and never sits on top of a row. A card with several lists adds their counts.
struct TodayCardMore: Equatable {
    var count: Int
    var action: () -> Void

    static func == (lhs: TodayCardMore, rhs: TodayCardMore) -> Bool { lhs.count == rhs.count }
}

struct TodayCardMoreKey: PreferenceKey {
    static var defaultValue: TodayCardMore?

    static func reduce(value: inout TodayCardMore?, nextValue: () -> TodayCardMore?) {
        guard let next = nextValue() else { return }
        if let current = value {
            value = TodayCardMore(count: current.count + next.count, action: current.action)
        } else {
            value = next
        }
    }
}

extension View {
    /// Says that `count` items did not fit. Nothing is drawn here: the card's header shows the pill.
    func todayCardMore(count: Int, action: @escaping () -> Void) -> some View {
        preference(key: TodayCardMoreKey.self, value: count > 0 ? TodayCardMore(count: count, action: action) : nil)
    }
}

/// The "+N more" pill in a card's header. Tapping it opens the full list.
struct DashboardMoreChip: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+\(count) more")
                .font(.caption.weight(.bold))
                // The pill shares the header with the title and the chevron, so it stops growing with the text
                // size before it takes the title's room.
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(HubTheme.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(HubTheme.tileQuiet, in: Capsule())
                .overlay(Capsule().stroke(HubTheme.line, lineWidth: 1))
                .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) more. Open the full list.")
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
    /// Let the rows tighten to `DashboardRow.compactHeight` when that shows more of them. Only for
    /// cards whose tiles are `DashboardRow`s.
    var allowsCompactRows = false
    @ViewBuilder let tile: (Item, CGFloat) -> Tile

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
            // Use the tighter rows when they reveal another one, or when not even one comfortable row fits (a row
            // is always shown, so it would run past the card's padding) and the tight one does.
            let comfortableOverflows = (comfortableHeights.first ?? 0) > geo.size.height
            let useCompact = allowsCompactRows
                && (compactFit.shown > comfortableFit.shown || (comfortableOverflows && (compactHeights.first ?? 0) <= geo.size.height))
            let heights = useCompact ? compactHeights : comfortableHeights
            let fit = useCompact ? compactFit : comfortableFit
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
            .todayCardMore(count: fit.hidden, action: onMore)
        }
    }

    private func fit(_ heights: [CGFloat], columns: Int, height: CGFloat) -> (shown: Int, hidden: Int, footerFits: Bool) {
        DashboardRowHelpers.fitWholeRows(
            itemHeights: heights,
            columns: columns,
            spacing: spacing,
            availableHeight: height,
            footerHeight: 0,
            footerGap: 0
        )
    }

    private func rowCount(shown: Int, columns: Int) -> Int {
        (shown + columns - 1) / columns
    }
}

