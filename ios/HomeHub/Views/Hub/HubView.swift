import SwiftUI

struct HubView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            HubNavView()
            VStack(spacing: 0) {
                HubHeaderView()
                hubContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .background(HubTheme.surface)
    }

    @ViewBuilder
    private var hubContent: some View {
        switch appState.selectedDestination {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarView()
        case .routines:
            RoutinesView()
        case .chores:
            ChoresView()
        case .meals:
            MealsView()
        case .snacks:
            SnacksView()
        case .recipes:
            RecipesView()
        case .profile:
            MyProfileView()
        case .settings:
            SettingsView()
        }
    }
}

struct HubNavView: View {
    @EnvironmentObject private var appState: AppState

    private var items: [HubDestination] {
        HubDestination.allCases.filter { destination in
            !destination.parentOnly || appState.canManageHousehold
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("H")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(HubTheme.sage)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 12)

            ForEach(items) { destination in
                Button {
                    appState.selectedDestination = destination
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: destination.systemImage)
                            .font(.title3)
                        Text(destination.label)
                            .font(.caption2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .foregroundStyle(
                        appState.selectedDestination == destination ? HubTheme.sage : HubTheme.muted
                    )
                    .background(
                        appState.selectedDestination == destination
                            ? HubTheme.sageSoft
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
        .frame(width: 104)
        .background(HubTheme.tile)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(HubTheme.line)
                .frame(width: 1)
        }
    }
}

struct HubHeaderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(appState.household?.name ?? "Home Hub")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(HubTheme.muted)
                    if let role = appState.household?.role, HouseholdRoles.isGuest(role: role) {
                        Text("Guest")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(HubTheme.sunSoft)
                            .clipShape(Capsule())
                    }
                }
                if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
                    Text(DateHelpers.headerDateLabel(timezone: timezone))
                        .font(.title2.weight(.semibold))
                }
            }
            Spacer()
            if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
                LiveClockView(timezone: timezone)
            }
            if let role = appState.household?.role, HouseholdRoles.isGuest(role: role) {
                Button("Sign Out") {
                    Task { await appState.signOut() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 78)
        .background(HubTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
    }
}
