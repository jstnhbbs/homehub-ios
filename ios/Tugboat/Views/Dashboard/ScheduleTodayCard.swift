import SwiftUI

/// The Schedule card at all three sizes.
///
/// Small is the next thing on the calendar. Medium lists what is left today. Large puts Today beside
/// Tomorrow. All-day events come first. The wording and the order come from `ScheduleCardSummary`.
struct ScheduleTodayCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    @State private var now = Date.now
    @State private var endTimer: Timer?

    private var timezone: TimeZone { TimeZone(identifier: dashboard.household.timezone) ?? .current }

    private var isConnected: Bool { appState.nativeCalendar.hasFullAccess }

    private var summary: ScheduleCardSummary {
        ScheduleCardSummary(
            today: isConnected ? appState.nativeTodayScheduleEvents : [],
            tomorrow: isConnected ? appState.nativeTomorrowScheduleEvents : [],
            now: now,
            timezone: timezone,
            isConnected: isConnected
        )
    }

    /// Only worth seeing which calendar an event came from once more than one is in play.
    private func showsCalendarName(_ events: [ScheduleEvent]) -> Bool {
        DashboardRowHelpers.showsCalendarName(events.map(\.calendarName))
    }

    var body: some View {
        TodayCardFrame(card: .schedule, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
        .onAppear {
            now = .now
            scheduleEndTimer()
        }
        .onDisappear { endTimer?.invalidate() }
        .onChange(of: appState.nativeTodayScheduleEvents.map(\.eventId)) { _, _ in scheduleEndTimer() }
        .onTick(every: 60) {
            now = Date()
            scheduleEndTimer()
        }
    }

    // MARK: Small

    private var small: some View {
        let summary = summary
        return TodayCardSmallBody(
            card: .schedule,
            action: isConnected ? nil : { openHubDestination(.settings) }
        ) {
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
            if !isConnected {
                notConnected
            } else if summary.todayLeft.isEmpty {
                TodayCardEmptyNote(text: summary.today.isEmpty ? "Nothing on the calendar today." : "Nothing left today.")
            } else {
                rows(summary.todayLeft, maxColumns: 2)
            }
        }
    }

    // MARK: Large

    @ViewBuilder
    private var large: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            if !isConnected {
                notConnected
            } else {
                HStack(alignment: .top, spacing: 12) {
                    TodayCardSection(title: "Today") {
                        if summary.todayLeft.isEmpty {
                            TodayCardEmptyNote(text: summary.today.isEmpty ? "Nothing today." : "Nothing left today.")
                        } else {
                            rows(summary.todayLeft, maxColumns: 1)
                        }
                    }
                    TodayCardSection(title: "Tomorrow") {
                        if summary.tomorrowAll.isEmpty {
                            TodayCardEmptyNote(text: "Nothing tomorrow.")
                        } else {
                            rows(summary.tomorrowAll, maxColumns: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private var notConnected: some View {
        Button { openHubDestination(.settings) } label: {
            TodayCardEmptyNote(text: "Connect a calendar to see today's events.")
        }
        .buttonStyle(.plain)
    }

    private func rows(_ events: [ScheduleEvent], maxColumns: Int) -> some View {
        let showsName = showsCalendarName(events)
        return WholeRowsGrid(
            items: events,
            minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidthWithStatus,
            maxColumns: maxColumns,
            itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
            onMore: { openHubDestination(.calendar) },
            allowsCompactRows: true
        ) { event, _ in
            ScheduleEventRow(event: event, timezone: timezone, showsCalendarName: showsName)
        }
    }

    /// Wakes the card when the next timed event ends, so it drops off the list on time.
    private func scheduleEndTimer() {
        endTimer?.invalidate()
        guard let nextEnd = DashboardHelpers.nextTimedEventEnd(after: now, in: appState.nativeTodayScheduleEvents) else { return }
        let interval = nextEnd.timeIntervalSince(now) + 0.05
        guard interval > 0 else { return }
        endTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            now = .now
            scheduleEndTimer()
        }
    }
}
