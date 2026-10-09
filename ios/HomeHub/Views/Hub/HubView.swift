import SwiftUI

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showMoreMenu = false
    @State private var lastPrimaryDestination: HubDestination = .dashboard
    @State private var compactMealsPath = NavigationPath()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                TabView(selection: compactTabSelection) {
                    ForEach(compactPrimaryDestinations, id: \.rawValue) { destination in
                        compactTab(for: destination)
                            // The tab container paints the system background, which is true black
                            // in dark mode; every page paints the app's own page color over it.
                            .background(HubTheme.canvas.ignoresSafeArea())
                            .id("tab-\(compactTabLayoutID)-\(destination.rawValue)")
                            .tabItem {
                                Label(destination.label, systemImage: destination.systemImage)
                                    .id("tab-item-\(compactTabLayoutID)-\(destination.rawValue)")
                            }
                            .tag(destination)
                    }
                    if !compactOverflowDestinations.isEmpty {
                        compactMoreTab
                            .background(HubTheme.canvas.ignoresSafeArea())
                            .id("tab-\(compactTabLayoutID)-\(HubDestination.more.rawValue)")
                            .tabItem {
                                Label(HubDestination.more.label, systemImage: HubDestination.more.systemImage)
                                    .id("tab-item-\(compactTabLayoutID)-\(HubDestination.more.rawValue)")
                            }
                            .tag(HubDestination.more)
                    }
                }
                .id(compactTabLayoutID)
                .tint(HubTheme.accentText)
                .background(HubTheme.surface)
                .overlay {
                    if showMoreMenu {
                        GeometryReader { proxy in
                            let layout = moreMenuLayout(in: proxy)

                            ZStack(alignment: .bottomTrailing) {
                                Color.black.opacity(0.08)
                                    .ignoresSafeArea(edges: .top)
                                    .padding(.bottom, layout.tabBarHeight)
                                    .onTapGesture {
                                        showMoreMenu = false
                                    }
                                    .accessibilityLabel("Dismiss more menu")

                                moreMenuCard
                                    .frame(width: layout.menuWidth)
                                    .padding(.trailing, layout.trailingInset)
                                    .padding(.bottom, layout.bottomInset)
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        .transition(.scale(scale: 0.92, anchor: UnitPoint(x: 0.86, y: 1)).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.2), value: showMoreMenu)
                .onAppear {
                    if compactPrimaryDestinations.contains(appState.selectedDestination) {
                        lastPrimaryDestination = appState.selectedDestination
                    }
                }
                .onChange(of: appState.selectedDestination) { _, newValue in
                    if compactPrimaryDestinations.contains(newValue) {
                        lastPrimaryDestination = newValue
                    }
                }
            } else {
                HStack(spacing: 0) {
                    // The sidebar and the top bar are navigation chrome, like a tab bar: they grow with the text
                    // up to a point and then stop, because a fixed-width sidebar cannot wrap its labels
                    // ("Chore / s") and nothing is gained by a header that fills the screen. The page itself
                    // keeps scaling all the way.
                    HubNavView()
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    VStack(spacing: 0) {
                        HubHeaderView()
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        content(for: appState.selectedDestination)
                            .frame(
                                maxWidth: regularContentMaxWidth(for: appState.selectedDestination),
                                maxHeight: .infinity,
                                alignment: .topLeading
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(24)
                    }
                }
                .background(HubTheme.surface)
            }
        }
        .environment(\.openHubDestination) { destination in
            appState.selectedDestination = destination
        }
    }

    private var compactTabSelection: Binding<HubDestination> {
        Binding(
            get: {
                if showMoreMenu || compactOverflowDestinations.contains(appState.selectedDestination) {
                    return compactOverflowDestinations.isEmpty ? appState.selectedDestination : .more
                }
                if compactPrimaryDestinations.contains(appState.selectedDestination) {
                    return appState.selectedDestination
                }
                return compactOverflowDestinations.isEmpty ? .dashboard : .more
            },
            set: { destination in
                if destination == .more {
                    showMoreMenu.toggle()
                    return
                }
                showMoreMenu = false
                lastPrimaryDestination = destination
                appState.selectedDestination = destination
            }
        )
    }

    @ViewBuilder
    private func compactTab(for destination: HubDestination) -> some View {
        if destination == .dashboard {
            DashboardView()
        } else if destination == .settings {
            SettingsStack(model: appState.settingsNavigation) {
                SettingsView(presentation: .tabRoot)
                    .hubPageBackground()
            }
        } else if destination == .meals {
            NavigationStack(path: $compactMealsPath) {
                compactPage(for: destination)
                    .hubPageBackground()
            }
        } else {
            compactPage(for: destination)
        }
    }

    private var compactMoreTab: some View {
        compactTab(for: moreTabDestination)
    }

    private var moreTabDestination: HubDestination {
        if compactOverflowDestinations.contains(appState.selectedDestination) {
            return appState.selectedDestination
        }
        if compactPrimaryDestinations.contains(appState.selectedDestination) {
            return appState.selectedDestination
        }
        return lastPrimaryDestination
    }

    private var compactTabBarDestinations: [HubDestination] {
        if compactOverflowDestinations.isEmpty {
            return compactPrimaryDestinations
        }
        return compactPrimaryDestinations + [.more]
    }

    private var compactTabLayoutID: String {
        compactTabBarDestinations.map(\.rawValue).joined(separator: "|")
    }

    private var moreMenuCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(compactOverflowDestinations.reversed().enumerated()), id: \.element.id) { index, destination in
                Button {
                    appState.selectedDestination = destination
                    showMoreMenu = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: destination.systemImage)
                            .font(.body.weight(.semibold))
                            .frame(width: 20)
                        Text(destination.label)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                    }
                    .foregroundStyle(
                        appState.selectedDestination == destination ? HubTheme.accentText : .primary
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(appState.selectedDestination == destination ? .isSelected : [])

                if index < compactOverflowDestinations.count - 1 {
                    Rectangle()
                        .fill(HubTheme.line.opacity(0.55))
                        .frame(height: 1)
                        .padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("More")
    }

    private func moreMenuLayout(in proxy: GeometryProxy) -> (
        menuWidth: CGFloat,
        trailingInset: CGFloat,
        bottomInset: CGFloat,
        tabBarHeight: CGFloat
    ) {
        let tabCount = CGFloat(compactTabBarDestinations.count)
        let tabWidth = proxy.size.width / max(tabCount, 1)
        let safeBottom = proxy.safeAreaInsets.bottom
        let tabBarHeight = safeBottom + 49
        // Wide enough for the longest name ("Celebrations") at the reader's text size, which a fixed
        // width broke mid-word; it still never goes past the screen's edge.
        let menuWidth = min(proxy.size.width - 16, max(DashboardMetrics.scaled(188, .body), min(188, max(156, tabWidth + 86))))
        let trailingInset = max(8, (tabWidth - menuWidth) / 2)
        return (menuWidth, trailingInset, max(10, tabBarHeight - 4), tabBarHeight)
    }

    private func compactPage(for destination: HubDestination) -> some View {
        content(for: destination)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HubTheme.surface)
    }

    @ViewBuilder
    private func content(for destination: HubDestination) -> some View {
        HubDestinationContent(destination: destination)
    }

    private func regularContentMaxWidth(for destination: HubDestination) -> CGFloat? {
        switch destination {
        case .settings:
            // A settings list reads badly stretched across a wide screen.
            900
        default:
            // Every other page uses the whole width; its own columns adapt to it.
            nil
        }
    }

    private var compactDestinations: [HubDestination] {
        let ordered = appState.hubModules.sidebarOrder.compactMap { HubDestination(module: $0) }
        var destinations = ([HubDestination.dashboard] + ordered).filter { destination in
            destination.isVisible(in: appState.hubModules)
        }
        if appState.canManageHousehold {
            destinations.append(.settings)
        }
        return destinations
    }

    private var compactPrimaryDestinations: [HubDestination] {
        let destinations = compactDestinations
        guard destinations.count > 5 else { return destinations }
        return Array(destinations.prefix(4))
    }

    private var compactOverflowDestinations: [HubDestination] {
        let destinations = compactDestinations
        guard destinations.count > 5 else { return [] }
        return Array(destinations.dropFirst(4))
    }
}

struct HubNavView: View {
    @EnvironmentObject private var appState: AppState
    private let sidebarVerticalPadding: CGFloat = 40
    private let sidebarItemHeight: CGFloat = 68
    private let sidebarItemSpacing: CGFloat = 8
    private let householdMarkHeight: CGFloat = 68

    private var items: [HubDestination] {
        let ordered = appState.hubModules.sidebarOrder.compactMap { HubDestination(module: $0) }
        var destinations = ([.dashboard] + ordered).filter { destination in
            destination.isVisible(in: appState.hubModules)
        }
        if appState.canManageHousehold {
            destinations.append(.settings)
        }
        return destinations
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = sidebarLayout(for: proxy.size.height)
            let primaryItems = Array(items.prefix(layout.primaryCount))
            let overflowItems = layout.showsMore ? Array(items.dropFirst(layout.primaryCount)) : []
            let moreIsSelected = overflowItems.contains(appState.selectedDestination)

            VStack(spacing: 8) {
                HouseholdMarkView(
                    name: appState.household?.name ?? "Porchlight",
                    photo: appState.household?.photo,
                    ownerName: appState.household?.ownerName,
                    size: 56
                )
                .padding(.bottom, 12)

                ForEach(primaryItems) { destination in
                    sidebarButton(destination)
                }

                if !overflowItems.isEmpty {
                    Menu {
                        ForEach(overflowItems) { destination in
                            Button {
                                appState.selectedDestination = destination
                            } label: {
                                Label(destination.label, systemImage: destination.systemImage)
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                            Text("More")
                                .font(.caption2.weight(.bold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .foregroundStyle(moreIsSelected ? HubTheme.accentText : HubTheme.muted)
                        .background(moreIsSelected ? HubTheme.sageSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(moreIsSelected ? .isSelected : [])
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 20)
        }
        .frame(width: 104)
        .background(HubTheme.tile)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(HubTheme.line)
                .frame(width: 1)
        }
    }

    private func sidebarButton(_ destination: HubDestination) -> some View {
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
                appState.selectedDestination == destination ? HubTheme.accentText : HubTheme.muted
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

    private func sidebarLayout(for height: CGFloat) -> (primaryCount: Int, showsMore: Bool) {
        let availableItemSlots = max(
            2,
            Int(
                floor(
                    (height - sidebarVerticalPadding - householdMarkHeight)
                        / (sidebarItemHeight + sidebarItemSpacing)
                )
            )
        )

        guard items.count > availableItemSlots else {
            return (items.count, false)
        }

        return (max(1, availableItemSlots - 1), true)
    }
}

struct HubHeaderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(appState.household?.name ?? "Porchlight")
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
            // Ambient readouts sit together on the trailing edge: temperature, then time.
            WeatherHeaderReadout()
            if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
                LiveClockView(timezone: timezone)
                    .padding(.leading, 4)
            }
            if let role = appState.household?.role, HouseholdRoles.isGuest(role: role) {
                Button("Sign Out") {
                    Task { await appState.signOut() }
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
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

struct HubDestinationContent: View {
    let destination: HubDestination
    var presentation: SettingsPresentation = .split

    var body: some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .calendar:
            CalendarView()
        case .groceries:
            GroceriesView()
        case .routines:
            RoutinesView()
        case .chores:
            ChoresView()
        case .meals:
            MealsView()
        case .sleep:
            NapsView(embeddedInHub: true)
        case .birthdays:
            BirthdaysView()
        case .notes:
            NotesView()
        case .profile:
            MyProfileView()
        case .settings:
            SettingsView(presentation: presentation)
        case .more:
            EmptyView()
        }
    }
}
