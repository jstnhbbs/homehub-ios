import SwiftUI

/// The Celebrations card (Birthdays, until a household adds an anniversary) at all three sizes.
///
/// Small is the next one and how long to wait. Medium lists the next few with their countdowns. Large lists
/// what is coming in date order, two across, with the age after each countdown. Today's celebration is also announced by the
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

    /// Two columns of tight rows in date order, left to right then down, so the rows line up. (It used to group
    /// by month in columns that flowed one into the next, which left the rows staggered and a month's heading
    /// stranded above half of its dates.) No summary line either: the countdown on each row says it.
    @ViewBuilder
    private var large: some View {
        let summary = summary
        if summary.items.isEmpty {
            emptyNote
        } else {
            WholeRowsGrid(
                items: summary.items,
                minimumColumnWidth: DashboardMetrics.scaled(150),
                maxColumns: 2,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.compactHeight },
                onMore: { openHubDestination(.birthdays) }
            ) { item, _ in
                row(item, summary: summary, ageInSubtitle: true)
                    .environment(\.dashboardRowIsCompact, true)
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

    /// `ageInSubtitle` puts the age after the countdown ("28 days · turns 37") instead of in a badge on the
    /// right, so a name in a narrow column has the whole width.
    private func row(_ item: BirthdayItem, summary: CelebrationCardSummary, ageInSubtitle: Bool = false) -> some View {
        let isToday = item.nextDate == summary.todayDate
        let countdown = BirthdayHelpers.countdownLabel(daysUntil: item.daysUntil)
        let subtitle = isToday
            ? (BirthdayToday.ageLine(item.upcomingAge, kind: item.kind) ?? "Today")
            : (ageInSubtitle ? [countdown, CelebrationCardSummary.ageText(item)].compactMap { $0 }.joined(separator: " · ") : countdown)
        return DashboardRow(
            title: item.name,
            subtitle: subtitle,
            leadingWidth: ageInSubtitle ? 16 : 28,
            tint: isToday ? .orange : nil,
            tintStrength: 0.14,
            outline: isToday ? Color.orange.opacity(0.5) : nil
        ) {
            if isToday {
                Image(systemName: "party.popper.fill")
                    .font(ageInSubtitle ? .caption : .subheadline)
                    .foregroundStyle(.orange)
            } else {
                Circle()
                    .fill(HubTheme.profileColor(item.color))
                    .frame(width: 10, height: 10)
            }
        } trailing: {
            // The age they turn (or the years an anniversary marks) as a small badge, so it never
            // crowds out the name or the countdown.
            if !isToday, !ageInSubtitle, (1...120).contains(item.upcomingAge) {
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
