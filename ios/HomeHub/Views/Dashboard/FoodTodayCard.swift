import SwiftUI

/// The Food card at all three sizes.
///
/// Small is tonight's dinner. Medium is today's three meals. Large is today's meals beside the dinners
/// for the rest of the week. The wording and the days come from `FoodCardSummary`.
struct FoodTodayCard: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    private var timezone: TimeZone { TimeZone(identifier: dashboard.household.timezone) ?? .current }

    private var summary: FoodCardSummary {
        FoodCardSummary(
            todayDate: dashboard.localDate,
            timezone: timezone,
            weekStartsOn: WeekStart.parseWeekStartsOn(dashboard.household.weekStartsOn),
            today: dashboard.meals,
            upcomingDinners: dashboard.upcomingDinners
        )
    }

    /// Today's three meals; `byRelevance` puts the ones still ahead first, for a card that can show only some.
    private func todayTiles(byRelevance: Bool) -> [MealTile] {
        let slots: [MealSlot] = byRelevance
            ? FoodCardSummary.slotsByRelevance(hour: DateHelpers.gregorian(in: timezone).component(.hour, from: Date()))
            : [.breakfast, .lunch, .dinner]
        return slots.map { slot in MealTile(slot: slot, meal: dashboard.meals.first { $0.slot == slot }) }
    }

    var body: some View {
        TodayCardFrame(card: .meals, fixedHeight: fixedHeight) {
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
        return TodayCardSmallBody(card: .meals) {
            VStack(alignment: .leading, spacing: 8) {
                TodayCardHeadline(
                    headline: summary.headline,
                    caption: summary.caption,
                    headlineLines: 3,
                    headlineFont: .title3.weight(.bold)
                )
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            meals(maxColumns: 3, byRelevance: true)
        }
    }

    // MARK: Large

    private var large: some View {
        let summary = summary
        return VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            HStack(alignment: .top, spacing: 12) {
                TodayCardSection(title: "Today") { meals(maxColumns: 1, byRelevance: false) }
                TodayCardSection(title: summary.restTitle) {
                    WholeRowsGrid(
                        items: summary.rest,
                        minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                        maxColumns: 1,
                        itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                        onMore: { openHubDestination(.meals) },
                        allowsCompactRows: true
                    ) { day, _ in
                        DashboardRow(title: FoodCardSummary.dish(day.dinner) ?? "Not planned") {
                            TodayCardDayChip(label: summary.weekday(day), highlighted: day.id == summary.rest.first?.id)
                        } trailing: {
                            EmptyView()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    // MARK: Pieces

    /// Only whole meal tiles are shown; one that does not fit becomes "+N more".
    private func meals(maxColumns: Int, byRelevance: Bool) -> some View {
        WholeRowsGrid(
            items: todayTiles(byRelevance: byRelevance),
            minimumColumnWidth: DashboardMetrics.scaled(125),
            // One column at the largest text sizes, where a slot's label and dish no longer fit side by side.
            maxColumns: dynamicTypeSize.isAccessibilitySize ? 1 : maxColumns,
            itemHeight: { tile, columnWidth in MealSlotRow.height(for: tile.meal, columnWidth: columnWidth) },
            onMore: { openHubDestination(.meals) }
        ) { tile, _ in
            MealSlotRow(slot: tile.slot, meal: tile.meal)
        }
    }
}
