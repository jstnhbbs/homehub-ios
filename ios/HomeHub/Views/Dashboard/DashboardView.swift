import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            let rowHeight = max(220, (proxy.size.height - 88) / 2)

            VStack(alignment: .leading, spacing: 16) {
                header

                if let dashboard = appState.dashboard {
                    HStack(alignment: .top, spacing: 16) {
                        DashboardPanel(
                            systemImage: "calendar",
                            title: "Today's Schedule",
                            destination: .calendar,
                            height: rowHeight
                        ) {
                            TodaySchedulePanel(
                                events: dashboard.scheduleEvents,
                                timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current,
                                connected: dashboard.calendarStatus.connected
                            ) {
                                appState.selectedDestination = .settings
                            }
                        }

                        DashboardPanel(
                            systemImage: "checklist",
                            title: "Today's Routines",
                            destination: .routines,
                            height: rowHeight
                        ) {
                            DashboardChecklistPanel(
                                isEmpty: dashboard.routineSteps.filter { !$0.completed }.isEmpty,
                                emptyTitle: dashboard.routineSteps.isEmpty
                                    ? "Add a morning or bedtime routine."
                                    : "All routines done for today!",
                                emptyAction: { appState.selectedDestination = .routines }
                            ) {
                                ForEach(dashboard.routineSteps.filter { !$0.completed }.prefix(5)) { step in
                                    RoutineCheckRow(step: step, localDate: dashboard.localDate)
                                }
                            }
                        }

                        DashboardPanel(
                            systemImage: "checkmark.square.fill",
                            title: "Chores",
                            destination: .chores,
                            height: rowHeight
                        ) {
                            let pending = dashboard.chores.filter { !$0.completed }
                            DashboardChecklistPanel(
                                isEmpty: pending.isEmpty,
                                emptyTitle: dashboard.chores.isEmpty
                                    ? "Add the first family chore."
                                    : "All chores done!",
                                emptyAction: { appState.selectedDestination = .chores }
                            ) {
                                ForEach(pending.prefix(5)) { chore in
                                    ChoreCheckRow(chore: chore)
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        DashboardPanel(
                            systemImage: "fork.knife",
                            title: "Today's Meals",
                            destination: .meals,
                            height: rowHeight,
                            background: HubTheme.sunSoft.opacity(0.5)
                        ) {
                            VStack(spacing: 8) {
                                ForEach([MealSlot.breakfast, .lunch, .dinner], id: \.self) { slot in
                                    MealSlotRow(
                                        slot: slot,
                                        meal: dashboard.meals.first { $0.slot == slot }
                                    )
                                }
                            }
                        }

                        DashboardPanel(
                            systemImage: "carrot.fill",
                            title: "Snacks",
                            destination: .snacks,
                            height: rowHeight
                        ) {
                            SnacksDashboardPanel(dashboard: dashboard)
                        }

                        NapsDashboardPanel(dashboard: dashboard, height: rowHeight)
                    }
                } else {
                    ProgressView("Loading today…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: 1500, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .refreshable {
            await appState.refreshDashboard()
        }
        .task {
            if appState.dashboard == nil {
                await appState.refreshDashboard()
            }
        }
        .sheet(isPresented: $appState.showNapsSheet) {
            NapsView()
                .environmentObject(appState)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good day, family")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(HubTheme.sage)
                Text("Here's what's happening today.")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
            }
            Spacer()
            if appState.canManageHousehold, let status = appState.dashboard?.calendarStatus {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status.connected ? "Calendars connected" : "No calendars")
                        .font(.caption.weight(.bold))
                    if let label = status.updatedLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(HubTheme.muted)
                    }
                    Button("Sync") {
                        Task {
                            try? await appState.api.syncCalendar(force: true)
                            await appState.refreshDashboard()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - Layout primitives

private struct DashboardPanel<Content: View>: View {
    @EnvironmentObject private var appState: AppState

    let systemImage: String
    let title: String
    let destination: HubDestination
    let height: CGFloat
    var background: Color = HubTheme.tile
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitleView(systemImage: systemImage, title: title) {
                appState.selectedDestination = destination
            }
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }
}

private struct DashboardChecklistPanel<Content: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptyAction: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isEmpty {
            EmptyStateView(text: emptyTitle, action: emptyAction)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    content()
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Schedule

private struct TodaySchedulePanel: View {
    let events: [ScheduleEvent]
    let timezone: TimeZone
    let connected: Bool
    let onConnect: () -> Void

    @State private var now = Date.now
    @State private var endTimer: Timer?

    private var visibleEvents: [ScheduleEvent] {
        Array(DashboardHelpers.upcomingScheduleEvents(events, now: now).prefix(5))
    }

    var body: some View {
        Group {
            if visibleEvents.isEmpty {
                EmptyStateView(text: emptyMessage, action: connected ? nil : onConnect)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(visibleEvents) { event in
                            ScheduleEventRow(event: event, timezone: timezone)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            now = .now
            scheduleEndTimer()
        }
        .onDisappear {
            endTimer?.invalidate()
        }
        .onChange(of: events.map(\.eventId)) { _, _ in
            scheduleEndTimer()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
            scheduleEndTimer()
        }
    }

    private var emptyMessage: String {
        if !connected {
            return "Connect a calendar to see today's events."
        }
        if events.isEmpty {
            return "Nothing on the calendar today."
        }
        return "Nothing left on the calendar today."
    }

    private func scheduleEndTimer() {
        endTimer?.invalidate()
        guard let nextEnd = DashboardHelpers.nextTimedEventEnd(after: now, in: events) else { return }
        let interval = nextEnd.timeIntervalSince(now) + 0.05
        guard interval > 0 else { return }
        endTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            now = .now
            scheduleEndTimer()
        }
    }
}

private struct ScheduleEventRow: View {
    let event: ScheduleEvent
    let timezone: TimeZone

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(HubTheme.profileColor(event.color))
                .frame(width: 5, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var subtitle: String {
        let time = event.allDay
            ? "All day"
            : DateHelpers.timeString(event.startsAt, timezone: timezone)
        if let calendarName = event.calendarName {
            return "\(time) · \(calendarName)"
        }
        return time
    }
}

// MARK: - Meals

private struct MealSlotRow: View {
    let slot: MealSlot
    let meal: Meal?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(slot.label.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)

            let lines = DashboardHelpers.mealLines(meal?.title ?? "")
            if lines.isEmpty {
                Text("Not planned")
                    .font(.subheadline.weight(.semibold))
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(index == 0 ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundStyle(index == 0 ? Color.primary : HubTheme.muted)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Snacks

private struct NapsDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData
    let height: CGFloat

    @State private var now = Date.now
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var childProfiles: [Profile] {
        NapHelpers.childProfiles(from: dashboard.profiles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitleView(systemImage: "moon.fill", title: "Sleep") {
                appState.showNapsSheet = true
            }
            if childProfiles.isEmpty {
                EmptyStateView(
                    text: "Add a child profile to log sleep.",
                    action: appState.canManageHousehold ? { appState.selectedDestination = .settings } : nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(childProfiles) { profile in
                            DashboardSleepRow(
                                profile: profile,
                                logs: dashboard.naps,
                                localDate: dashboard.localDate,
                                timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current,
                                now: now
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)

                Text("Tap Sleep to log naps, bedtime, or edit times.")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
        .onReceive(timer) { date in
            now = date
        }
    }
}

private struct DashboardSleepRow: View {
    @EnvironmentObject private var appState: AppState
    let profile: Profile
    let logs: [NapLog]
    let localDate: String
    let timezone: TimeZone
    let now: Date

    var body: some View {
        let status = NapHelpers.getChildDashboardSleepStatus(
            logs: logs,
            profileId: profile.id,
            localDate: localDate,
            timezone: timezone,
            now: now
        )
        let secondary = NapHelpers.dashboardSleepSecondary(for: status)

        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(HubTheme.profileColor(profile.color))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let activeLogId = status.activeLogId {
                        Button(actionLabel(for: status)) {
                            Task {
                                try? await appState.api.endNap(napId: activeLogId)
                                await appState.refreshDashboard()
                            }
                        }
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(HubTheme.sage)
                        .buttonStyle(.plain)
                        .padding(.top, 1)
                    }
                }
                Text(primaryText(for: status))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(2)
                if let secondary {
                    Text(secondary)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func primaryText(for status: ChildDashboardSleepStatus) -> String {
        switch status.state {
        case .napping:
            return "Nap · asleep \(NapHelpers.formatDuration(minutes: status.durationMinutes))"
        case .inBed:
            let started = DateHelpers.timeString(status.startedAt ?? now, timezone: timezone)
            return "In bed since \(started) · \(NapHelpers.formatDuration(minutes: status.durationMinutes))"
        case .awake:
            return "Awake \(NapHelpers.formatDuration(minutes: status.durationMinutes))"
        case .empty:
            return "No sleep logged today"
        }
    }

    private func actionLabel(for status: ChildDashboardSleepStatus) -> String {
        status.state == .inBed ? "Wake up" : "End"
    }
}

private struct SnacksDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    private var eaten: Set<String> { Set(dashboard.snackEaten) }
    private var sortedSnacks: [String] {
        SnackHelpers.sortedSnackOptions(dashboard.snackOptions, eaten: eaten)
    }

    var body: some View {
        VStack(spacing: 8) {
            if dashboard.snackOptions.isEmpty {
                EmptyStateView(
                    text: "Add snack options for the family.",
                    action: { appState.selectedDestination = .snacks }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(sortedSnacks.prefix(6), id: \.self) { snack in
                            SnackCheckRow(
                                label: snack,
                                localDate: dashboard.localDate,
                                isEaten: eaten.contains(snack)
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if !dashboard.snackOptions.isEmpty {
                Text("\(dashboard.snackEaten.count) of \(dashboard.snackOptions.count) eaten today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Check rows

private struct RoutineCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let step: RoutineStepRow
    let localDate: String
    @State private var isChecked: Bool

    init(step: RoutineStepRow, localDate: String) {
        self.step = step
        self.localDate = localDate
        _isChecked = State(initialValue: step.completed)
    }

    var body: some View {
        CheckItemView(
            label: step.label,
            detail: step.profileId == nil ? step.routineName : profileName,
            color: profileColor,
            isChecked: $isChecked,
            removeWhenChecked: true
        ) {
            try? await appState.api.toggleRoutineStep(
                ToggleRoutineStepRequest(stepId: step.id, localDate: localDate)
            )
            await appState.refreshDashboard()
        }
    }

    private var profileName: String {
        appState.dashboard?.profiles.first { $0.id == step.profileId }?.name ?? step.routineName
    }

    private var profileColor: String? {
        appState.dashboard?.profiles.first { $0.id == step.profileId }?.color
    }
}

private struct ChoreCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let chore: ChoreRow
    @State private var isChecked: Bool

    init(chore: ChoreRow) {
        self.chore = chore
        _isChecked = State(initialValue: chore.completed)
    }

    var body: some View {
        CheckItemView(
            label: chore.title,
            detail: appState.dashboard?.profiles.first { $0.id == chore.profileId }?.name ?? "Anyone",
            color: profileColor,
            isChecked: $isChecked,
            removeWhenChecked: true
        ) {
            try? await appState.api.toggleChore(
                ToggleChoreRequest(choreId: chore.id, periodKey: chore.periodKey)
            )
            await appState.refreshDashboard()
        }
    }

    private var profileColor: String? {
        appState.dashboard?.profiles.first { $0.id == chore.profileId }?.color
    }
}

private struct SnackCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let label: String
    let localDate: String
    let isEaten: Bool
    @State private var isChecked: Bool

    init(label: String, localDate: String, isEaten: Bool) {
        self.label = label
        self.localDate = localDate
        self.isEaten = isEaten
        _isChecked = State(initialValue: isEaten)
    }

    var body: some View {
        CheckItemView(label: label, isChecked: $isChecked) {
            try? await appState.api.toggleSnack(
                ToggleSnackRequest(localDate: localDate, snackLabel: label)
            )
            await appState.refreshDashboard()
        }
        .onChange(of: isEaten) { _, eaten in
            isChecked = eaten
        }
    }
}
