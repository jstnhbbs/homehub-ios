import SwiftUI

/// The Celebrations card (Birthdays, until a household adds an anniversary) at all three sizes.
///
/// Small is the next one and how long to wait. Medium lists the next few with their countdowns. Large lists
/// what is coming under a heading for each month, with ages. Today's celebration is also announced by the
/// banner at the top of Today. The wording and the months come from `CelebrationCardSummary`.
struct CelebrationsTodayCard: View {
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    private var timezone: TimeZone { TimeZone(identifier: dashboard.household.timezone) ?? .current }

    private var summary: CelebrationCardSummary {
        // Today's date in the household's time zone, so a dashboard loaded yesterday still says "today".
        CelebrationCardSummary(
            items: dashboard.upcomingBirthdays,
            todayDate: DateHelpers.localDateIn(timezone: timezone),
            timezone: timezone
        )
    }

    var body: some View {
        TodayCardFrame(card: .birthdays, fixedHeight: fixedHeight) {
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
        return TodayCardSmallBody(card: .birthdays) {
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
                // The countdown is the point of this card, so rows keep their full height.
                WholeRowsGrid(
                    items: summary.items,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                    maxColumns: 3,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.birthdays) }
                ) { item, _ in
                    row(item, summary: summary)
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
            if summary.items.isEmpty {
                emptyNote
            } else {
                GeometryReader { geo in
                    let layout = ColumnFit.fit(
                        summary.entries,
                        isItem: { $0.isItem },
                        columnCount: geo.size.width >= 300 ? 2 : 1,
                        itemHeight: DashboardRow<EmptyView, EmptyView>.height,
                        headerHeight: DashboardMetrics.scaled(18, .caption1),
                        spacing: 8,
                        footerHeight: DashboardMoreFooter.height,
                        availableHeight: geo.size.height
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(layout.columns.enumerated()), id: \.offset) { _, column in
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(column) { entry in
                                        switch entry {
                                        case .header(let month):
                                            Text(month)
                                                .font(.caption.weight(.heavy))
                                                .foregroundStyle(HubTheme.muted)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .accessibilityAddTraits(.isHeader)
                                        case .item(let item):
                                            row(item, summary: summary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                        if layout.hiddenItems > 0 {
                            DashboardMoreFooter(count: layout.hiddenItems) { openHubDestination(.birthdays) }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    // MARK: Pieces

    private var emptyNote: some View {
        Button { openHubDestination(.birthdays) } label: {
            TodayCardEmptyNote(text: "Add a birthday or anniversary to keep dates in view.")
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: BirthdayItem, summary: CelebrationCardSummary) -> some View {
        let isToday = item.nextDate == summary.todayDate
        let subtitle = isToday
            ? (BirthdayToday.ageLine(item.upcomingAge, kind: item.kind) ?? "Today")
            : BirthdayHelpers.countdownLabel(daysUntil: item.daysUntil)
        return DashboardRow(
            title: item.name,
            subtitle: subtitle,
            tint: isToday ? .orange : nil,
            tintStrength: 0.14,
            outline: isToday ? Color.orange.opacity(0.5) : nil
        ) {
            if isToday {
                Image(systemName: "party.popper.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else {
                Circle()
                    .fill(HubTheme.profileColor(item.color))
                    .frame(width: 10, height: 10)
            }
        } trailing: {
            // The age they turn (or the years an anniversary marks) as a small badge, so it never
            // crowds out the name or the countdown.
            if !isToday, (1...120).contains(item.upcomingAge) {
                Text(item.kind == .anniversary ? "\(item.upcomingAge)y" : "\(item.upcomingAge)")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(HubTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(HubTheme.tile, in: Capsule())
                    .accessibilityLabel(CelebrationCardSummary.ageText(item) ?? "")
            }
        }
    }
}
