import SwiftUI

/// The Groceries card at all three sizes.
///
/// Small is how many items are left to buy. Medium lists them, tickable. Large reads like the list on
/// paper: under an aisle heading each (when the list has aisles), then what was just checked off, which
/// can be unticked again. The grouping and the fitting come from `GroceryCardSummary`.
struct GroceriesTodayCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    private var usesReminders: Bool {
        appState.groceriesUseNativeReminders
    }

    private var summary: GroceryCardSummary {
        if usesReminders {
            let all = appState.nativeGroceryItems
            return GroceryCardSummary(items: all.filter { !$0.checked }, checked: all.filter(\.checked), isServerBacked: false)
        }
        return GroceryCardSummary(items: dashboard.groceryItems, checked: dashboard.checkedGroceryItems, isServerBacked: true)
    }

    var body: some View {
        TodayCardFrame(card: .groceries, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
    }

    // MARK: Small

    private var small: some View {
        let summary = summary
        return TodayCardSmallBody(card: .groceries) {
            VStack(alignment: .leading, spacing: 8) {
                TodayCardHeadline(headline: summary.headline, caption: summary.caption)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Medium

    @ViewBuilder
    private var medium: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            if summary.items.isEmpty {
                emptyNote
            } else {
                WholeRowsGrid(
                    items: summary.items,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                    maxColumns: 3,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.groceries) },
                    allowsCompactRows: true
                ) { item, _ in
                    DashboardGroceryItemRow(item: item)
                }
            }
        }
    }

    // MARK: Large

    @ViewBuilder
    private var large: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            if summary.items.isEmpty && summary.checked.isEmpty {
                emptyNote
            } else {
                GeometryReader { geo in
                    let columnCount = geo.size.width >= 300 ? 2 : 1
                    let layout = GroceryCardSummary.fit(
                        summary.entries,
                        columnCount: columnCount,
                        itemHeight: DashboardRow<EmptyView, EmptyView>.compactHeight,
                        headerHeight: DashboardMetrics.scaled(18, .caption1),
                        spacing: 8,
                        footerHeight: 0,
                        availableHeight: geo.size.height
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(layout.columns.enumerated()), id: \.offset) { _, column in
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(column) { entry in
                                        entryView(entry, summary: summary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                        .environment(\.dashboardRowIsCompact, true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .todayCardMore(count: layout.hiddenItems) { openHubDestination(.groceries) }
                }
            }
        }
    }

    // MARK: Pieces

    private var emptyNote: some View {
        Button { openHubDestination(.groceries) } label: {
            TodayCardEmptyNote(text: "Start a shared grocery list.")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func entryView(_ entry: GroceryEntry, summary: GroceryCardSummary) -> some View {
        switch entry {
        case .header(let name):
            Text(name)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        case .item(let item):
            if item.checked {
                GroceryCheckedRow(item: item)
            } else {
                DashboardGroceryItemRow(item: item, showsCategory: !summary.isGrouped)
            }
        }
    }
}

/// An item that was just checked off, shown struck through; tap to put it back on the list.
private struct GroceryCheckedRow: View {
    @EnvironmentObject private var appState: AppState
    let item: GroceryItem
    @State private var isWorking = false

    var body: some View {
        Button { Task { await uncheck() } } label: {
            DashboardRow(title: item.title, isDone: true) {
                DashboardCheckMarker(isChecked: true)
            } trailing: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking || !appState.canManageHousehold)
        .accessibilityValue("Checked off")
        .accessibilityHint("Put it back on the list")
        .accessibilityAddTraits(.isToggle)
    }

    private func uncheck() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.setGroceryItemChecked(id: item.id, checked: false)
        } catch {
            appState.report(error)
        }
    }
}
