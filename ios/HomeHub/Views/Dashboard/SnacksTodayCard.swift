import SwiftUI

/// The Snacks card at all three sizes.
///
/// Small is how many of today's snacks have been had. Medium lists them to tick off (with a circle for
/// each child when snacks are tracked per child). Large splits what is left from what has been eaten, or
/// for per-child households shows each child's progress beside the list.
struct SnacksTodayCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    private var eaten: Set<String> { Set(dashboard.snackEaten) }
    private var sorted: [SnackListItem] {
        SnackHelpers.sortedSnackOptions(dashboard.snackOptions, eaten: eaten).map(SnackListItem.init)
    }
    private var children: [Profile] { NapHelpers.childProfiles(from: dashboard.profiles) }
    /// Each child has their own circle on each snack.
    private var perChild: Bool { dashboard.snacksPerChild && !children.isEmpty }
    private var total: Int { dashboard.snackOptions.count }
    private var had: Int { dashboard.snackEaten.count }

    private var headline: String { total == 0 ? "None set up" : "\(had) of \(total)" }
    private var caption: String {
        if total == 0 { return "Add snack options" }
        return perChild ? "eaten by everyone" : "eaten today"
    }
    private var line: String {
        if total == 0 { return "No snacks set up" }
        return perChild ? "\(had) of \(total) eaten by everyone" : "\(had) of \(total) eaten today"
    }

    private func openSnacks() {
        if appState.hubModules.snacks { appState.pendingFoodSection = .snacks }
        openHubDestination(.meals)
    }

    var body: some View {
        TodayCardFrame(card: .snacks, fixedHeight: fixedHeight, onNavigate: openSnacks) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
    }

    // MARK: Small

    private var small: some View {
        TodayCardSmallBody(card: .snacks, action: openSnacks) {
            VStack(alignment: .leading, spacing: 8) {
                TodayCardHeadline(headline: headline, caption: caption)
                Spacer(minLength: 0)
                if total > 0 {
                    ProgressView(value: Double(had), total: Double(total))
                        .tint(HubTheme.accentText)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Medium

    @ViewBuilder
    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: line)
            if total == 0 {
                emptyNote
            } else {
                snackGrid(sorted, maxColumns: 3)
            }
        }
    }

    // MARK: Large

    @ViewBuilder
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: line)
            if total == 0 {
                emptyNote
            } else if perChild {
                HStack(alignment: .top, spacing: 12) {
                    TodayCardSection(title: "Snacks") { snackGrid(sorted, maxColumns: 1) }
                    TodayCardSection(title: "Had so far") {
                        SnackChildProgress(
                            children: children,
                            counts: SnackHelpers.eatenCounts(
                                options: dashboard.snackOptions,
                                childIds: children.map(\.id),
                                in: dashboard.snackCompletions
                            ),
                            total: total
                        )
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    TodayCardSection(title: "To eat") {
                        let pending = sorted.filter { !eaten.contains($0.label) }
                        if pending.isEmpty {
                            TodayCardEmptyNote(text: "All eaten!")
                        } else {
                            snackGrid(pending, maxColumns: 1)
                        }
                    }
                    TodayCardSection(title: "Eaten") {
                        let done = sorted.filter { eaten.contains($0.label) }
                        if done.isEmpty {
                            TodayCardEmptyNote(text: "Nothing yet.")
                        } else {
                            snackGrid(done, maxColumns: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private var emptyNote: some View {
        Button(action: openSnacks) {
            TodayCardEmptyNote(text: "Add snack options for the family.")
        }
        .buttonStyle(.plain)
    }

    private func snackGrid(_ items: [SnackListItem], maxColumns: Int) -> some View {
        WholeRowsGrid(
            items: items,
            minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
            maxColumns: maxColumns,
            itemHeight: { item, columnWidth in
                perChild
                    ? DashboardCheckTile.snackChildHeight(title: item.label, childCount: children.count, columnWidth: columnWidth)
                    : DashboardRow<EmptyView, EmptyView>.height
            },
            onMore: openSnacks,
            allowsCompactRows: !perChild
        ) { item, _ in
            if perChild {
                SnackChildTile(
                    snack: item.label,
                    children: children,
                    records: dashboard.snackCompletions,
                    isDone: eaten.contains(item.label),
                    localDate: dashboard.localDate
                )
            } else {
                DashboardSnackCheckRow(
                    label: item.label,
                    localDate: dashboard.localDate,
                    isEaten: eaten.contains(item.label)
                )
            }
        }
    }
}
