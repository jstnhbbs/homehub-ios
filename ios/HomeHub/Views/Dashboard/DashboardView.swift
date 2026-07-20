import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let dashboard = appState.dashboard {
                    scheduleSection(dashboard)
                    routinesSection(dashboard)
                    choresSection(dashboard)
                    mealsSection(dashboard)
                    snacksSection(dashboard)
                } else {
                    ProgressView("Loading today…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await appState.refreshDashboard()
        }
        .task {
            if appState.dashboard == nil {
                await appState.refreshDashboard()
            }
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
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
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

    private func scheduleSection(_ dashboard: DashboardData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitleView(systemImage: "calendar", title: "Today's Schedule") {
                    appState.selectedDestination = .calendar
                }
                if dashboard.scheduleEvents.isEmpty {
                    EmptyStateView(text: "Connect a calendar in Settings.")
                } else {
                    ForEach(dashboard.scheduleEvents) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.body.weight(.semibold))
                                if let calendarName = event.calendarName {
                                    Text(calendarName)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(HubTheme.profileColor(event.color))
                                }
                            }
                            Spacer()
                            if let timezone = TimeZone(identifier: dashboard.household.timezone) {
                                Text(
                                    event.allDay
                                        ? "All day"
                                        : DateHelpers.timeString(event.startsAt, timezone: timezone)
                                )
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                            }
                        }
                        .padding(12)
                        .background(HubTheme.tileQuiet)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private func routinesSection(_ dashboard: DashboardData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitleView(systemImage: "checklist", title: "Today's Routines") {
                    appState.selectedDestination = .routines
                }
                let pending = dashboard.routineSteps.filter { !$0.completed }
                if pending.isEmpty {
                    EmptyStateView(
                        text: dashboard.routineSteps.isEmpty
                            ? "Add a morning or bedtime routine."
                            : "All routines done for today!"
                    ) {
                        appState.selectedDestination = .routines
                    }
                } else {
                    ForEach(pending.prefix(5)) { step in
                        RoutineCheckRow(step: step, localDate: dashboard.localDate)
                    }
                }
            }
        }
    }

    private func choresSection(_ dashboard: DashboardData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitleView(systemImage: "checkmark.square.fill", title: "Chores") {
                    appState.selectedDestination = .chores
                }
                let pending = dashboard.chores.filter { !$0.completed }
                if pending.isEmpty {
                    EmptyStateView(text: "Add the first family chore.") {
                        appState.selectedDestination = .chores
                    }
                } else {
                    ForEach(pending.prefix(5)) { chore in
                        ChoreCheckRow(chore: chore)
                    }
                }
            }
        }
    }

    private func mealsSection(_ dashboard: DashboardData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitleView(systemImage: "fork.knife", title: "Today's Meals") {
                    appState.selectedDestination = .meals
                }
                ForEach([MealSlot.breakfast, .lunch, .dinner], id: \.self) { slot in
                    let meal = dashboard.meals.first { $0.slot == slot }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.label.uppercased())
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        Text(meal?.title.isEmpty == false ? meal!.title : "Not planned")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .background(HubTheme.sunSoft.opacity(0.5))
    }

    private func snacksSection(_ dashboard: DashboardData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitleView(systemImage: "carrot.fill", title: "Snacks") {
                    appState.selectedDestination = .snacks
                }
                let eaten = Set(dashboard.snackEaten)
                let pending = dashboard.snackOptions.filter { !eaten.contains($0) }
                if pending.isEmpty {
                    EmptyStateView(
                        text: dashboard.snackOptions.isEmpty
                            ? "Add snack options for the family."
                            : "All snacks eaten for today!"
                    ) {
                        appState.selectedDestination = .snacks
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(pending.prefix(6), id: \.self) { snack in
                            SnackCheckRow(label: snack, localDate: dashboard.localDate)
                        }
                    }
                }
                if !dashboard.snackOptions.isEmpty {
                    Text("\(dashboard.snackEaten.count) of \(dashboard.snackOptions.count) eaten today")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct RoutineCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let step: RoutineStepRow
    let localDate: String
    @State private var isChecked = false

    var body: some View {
        CheckItemView(
            label: step.label,
            detail: step.profileId == nil ? step.routineName : profileName,
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
            isChecked: $isChecked
        ) {
            try? await appState.api.toggleChore(
                ToggleChoreRequest(choreId: chore.id, periodKey: chore.periodKey)
            )
            await appState.refreshDashboard()
        }
    }
}

private struct SnackCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let label: String
    let localDate: String
    @State private var isChecked = false

    var body: some View {
        CheckItemView(label: label, isChecked: $isChecked, removeWhenChecked: true) {
            try? await appState.api.toggleSnack(
                ToggleSnackRequest(localDate: localDate, snackLabel: label)
            )
            await appState.refreshDashboard()
        }
    }
}
