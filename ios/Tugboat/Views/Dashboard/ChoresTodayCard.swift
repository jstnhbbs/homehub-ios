import SwiftUI

/// The Chores card at all three sizes.
///
/// Small is a glance: what is left and what is next. Medium adds today's chores, which can be ticked off.
/// Large splits into Today and Coming up, so the week ahead is visible too. The wording and the order
/// come from `ChoreCardSummary`.
struct ChoresTodayCard: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    private var summary: ChoreCardSummary {
        ChoreCardSummary(
            today: dashboard.chores,
            later: dashboard.laterChores,
            todayDate: dashboard.localDate,
            timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current
        )
    }

    private func assignee(_ chore: ChoreRow) -> Profile? {
        dashboard.profiles.first { $0.id == chore.profileId }
    }

    private func assigneeName(_ chore: ChoreRow) -> String {
        assignee(chore)?.name ?? "Anyone"
    }

    /// Who each chore in `chores` is for, as a short name and their color, or nil when the chores are all
    /// for the same person (the name would only repeat).
    private func people(for chores: [ChoreRow]) -> (ChoreRow) -> ChorePersonMark? {
        let names = chores.map(assigneeName)
        guard DashboardRowHelpers.showsAssignee(names) else { return { _ in nil } }
        return { chore in
            let full = assigneeName(chore)
            let color = assignee(chore).map { HubTheme.profileColor($0.color) }
            return ChorePersonMark(name: ChoreCardSummary.shortName(full, among: names), color: color)
        }
    }

    var body: some View {
        TodayCardFrame(card: .chores, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
    }

    // MARK: Small

    private var small: some View {
        TodayCardSmallBody(card: .chores) {
            VStack(alignment: .leading, spacing: 8) {
                TodayCardHeadline(headline: summary.headline, caption: summary.caption)
                Spacer(minLength: 0)
                if let progress = summary.progress {
                    ProgressView(value: min(max(progress, 0), 1))
                        .tint(HubTheme.accentText)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            todayRows(maxColumns: 3)
        }
    }

    // MARK: Large

    @ViewBuilder
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            // Two sections side by side; at the largest text sizes, one above the other.
            let sections = Group {
                TodayCardSection(title: "Today") { todayRows(maxColumns: 1) }
                TodayCardSection(title: "Coming up") { comingUpRows }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { sections }
            } else {
                HStack(alignment: .top, spacing: 12) { sections }
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func todayRows(maxColumns: Int) -> some View {
        let pending = summary.pending
        if pending.isEmpty {
            TodayCardEmptyNote(text: dashboard.chores.isEmpty ? "No chores due today." : "All chores done!")
        } else {
            // The "who" is only worth showing when chores are for different people.
            let person = people(for: pending)
            WholeRowsGrid(
                items: pending,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: maxColumns,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.chores) },
                allowsCompactRows: true
            ) { chore, _ in
                ChoreCheckRow(chore: chore, person: person(chore))
            }
        }
    }

    @ViewBuilder
    private var comingUpRows: some View {
        let later = dashboard.laterChores
        if later.isEmpty {
            TodayCardEmptyNote(text: "Nothing coming up.")
        } else {
            let person = people(for: later)
            WholeRowsGrid(
                items: later,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: 1,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.chores) },
                allowsCompactRows: true
            ) { chore, _ in
                DashboardRow(
                    title: chore.title,
                    subtitle: summary.laterSubtitle(for: chore, assignee: person(chore)?.name),
                    subtitlePersonColor: person(chore)?.color
                ) {
                    TodayCardDayChip(label: summary.weekdayLabel(for: chore), highlighted: summary.isTomorrow(chore))
                } trailing: {
                    EmptyView()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(chore.title), \(summary.dayLabel(for: chore))")
            }
        }
    }
}
