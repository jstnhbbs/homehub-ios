import SwiftUI

/// The Sleep card at all three sizes.
///
/// Small is how long the longest sleeper has been asleep, or else how long the child awake the longest has
/// been awake. Medium has a row for each child, with a button to end a running sleep. Large has a column
/// for each child with their day's sleeps and times. The wording comes from `SleepCardSummary`.
struct SleepTodayCard: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @EnvironmentObject private var appState: AppState

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    @State private var now = Date.now

    private var timezone: TimeZone { TimeZone(identifier: dashboard.household.timezone) ?? .current }

    private var children: [Profile] {
        // Anyone asleep comes first, so with a big family in a short card the children whose sleep can be
        // ended are the ones visible.
        let all = NapHelpers.childProfiles(from: dashboard.profiles)
        let asleep = all.filter { NapHelpers.activeSleep(for: $0.id, in: dashboard.naps) != nil }
        return asleep + all.filter { child in !asleep.contains { $0.id == child.id } }
    }

    private var summary: SleepCardSummary {
        SleepCardSummary(children: children, logs: dashboard.naps, localDate: dashboard.localDate, timezone: timezone, now: now)
    }

    var body: some View {
        TodayCardFrame(card: .sleep, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
        .onTick(every: 30) { now = Date() }
    }

    // MARK: Small

    private var small: some View {
        let summary = summary
        return TodayCardSmallBody(card: .sleep) {
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
            if children.isEmpty {
                emptyNote
            } else {
                // Two children side by side on a phone (three on an iPad): the rows use the short wording, so
                // they need only the narrow minimum width. One row used to take the whole card and leave
                // the next child behind "+1 more" with room to spare.
                WholeRowsGrid(
                    items: children,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                    maxColumns: 3,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.sleep) },
                    allowsCompactRows: true
                ) { profile, _ in
                    DashboardSleepRow(profile: profile, logs: dashboard.naps, localDate: dashboard.localDate, timezone: timezone, now: now,
                                      shortStatus: summary.shortStatusText(for: profile),
                                      spokenStatus: summary.spokenStatusText(for: profile))
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
            if children.isEmpty {
                emptyNote
            } else {
                GeometryReader { geo in
                    let columns = max(1, min(3, Int((geo.size.width + 10) / 160)))
                    let shown = Array(children.prefix(columns))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(shown) { child in
                                SleepChildColumn(child: child, summary: summary, timezone: timezone, now: now)
                            }
                        }
                    }
                    .todayCardMore(count: children.count - shown.count) { openHubDestination(.sleep) }
                }
            }
        }
    }

    private var emptyNote: some View {
        Button(action: { if appState.canManageHousehold { openHubDestination(.settings) } }) {
            TodayCardEmptyNote(text: "Add a child profile to log sleep.")
        }
        .buttonStyle(.plain)
    }
}

/// One child's column on the Large card: who they are and how they are now, then the day's sleeps.
private struct SleepChildColumn: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let child: Profile
    let summary: SleepCardSummary
    let timezone: TimeZone
    let now: Date

    private func statusText(_ status: ChildDashboardSleepStatus) -> String {
        let duration = NapHelpers.formatDuration(minutes: status.durationMinutes)
        switch status.state {
        case .napping: return "Asleep \(duration)"
        case .inBed: return "In bed \(duration)"
        case .awake: return "Awake \(duration)"
        case .empty: return "Nothing logged"
        }
    }

    var body: some View {
        let status = summary.status(for: child)
        let entries = summary.entries(for: child)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ProfileAvatarView(name: child.name, avatar: child.avatar, color: child.color, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(child.name)
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)
                    Text(statusText(status))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if entries.isEmpty {
                TodayCardEmptyNote(text: "No sleep yet.")
            } else {
                WholeRowsGrid(
                    items: entries,
                    minimumColumnWidth: 120,
                    maxColumns: 1,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.sleep) },
                    allowsCompactRows: true
                ) { entry, _ in
                    // No marker: the width is better spent on the times.
                    DashboardRow(title: "\(entry.title) · \(entry.duration)", subtitle: entry.range, showsLeading: false) {
                        EmptyView()
                    } trailing: {
                        EmptyView()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
