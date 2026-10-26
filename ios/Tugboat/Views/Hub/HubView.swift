import SwiftUI

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var moreMenuWidth = 188.0
    @ScaledMetric(relativeTo: .body) private var moreMenuLineHeight = 22.0
    @ScaledMetric(relativeTo: .body) private var moreMenuIconWidth = 20.0
    @State private var showMoreMenu = false
    /// A picture of the page the menu opened over, shown as the More tab's content so the page behind the menu does not
    /// move; the real page is untouched and comes back when the menu closes.
    @State private var moreSnapshot: UIImage?
    /// The tab bar's hook already handled this tap, so the binding's setter must not handle it a second time.
    @State private var moreTapHandled = false
    /// On a phone Settings opens over whatever page is showing, as a sheet, instead of replacing it.
    @State private var showingSettingsSheet = false
    @State private var destinationBeforeSettings: HubDestination = .dashboard
    @State private var lastPrimaryDestination: HubDestination = .dashboard
    @State private var compactMealsPath = NavigationPath()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                TabView(selection: compactTabSelection) {
                    ForEach(compactPrimaryDestinations, id: \.rawValue) { destination in
                        compactTab(for: destination)
                            .background {
                                // Inside a tab, so it can find the tab bar controller (outside the tab view it cannot).
                                if destination == compactPrimaryDestinations.first {
                                    MoreTabInterceptor(hasMoreTab: !compactOverflowDestinations.isEmpty) { snapshot in
                                        moreTapHandled = true
                                        if !showMoreMenu { moreSnapshot = snapshot }
                                        showMoreMenu.toggle()
                                    }
                                }
                            }
                            .environment(\.hubWash, wash(for: destination))
                            // The tab container paints the system background, which is true black
                            // in dark mode; every page paints the app's own page color over it.
                            .hubPageBackground()
                            .id("tab-\(compactTabLayoutID)-\(destination.rawValue)")
                            .tabItem {
                                Label(destination.label, systemImage: destination.systemImage)
                                    .id("tab-item-\(compactTabLayoutID)-\(destination.rawValue)")
                            }
                            .tag(destination)
                    }
                    if !compactOverflowDestinations.isEmpty {
                        moreTabContent
                            .environment(\.hubWash, wash(for: moreTabDestination))
                            .hubPageBackground()
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
                .hubSurfaceBackground()
                .accessibilityHidden(showMoreMenu)
                .overlay {
                    if showMoreMenu {
                        GeometryReader { proxy in
                            let layout = moreMenuLayout(in: proxy)

                            ZStack(alignment: .bottomTrailing) {
                                Button {
                                    showMoreMenu = false
                                } label: {
                                    // No dimming: the menu is a small glass card over a page that stays as it is.
                                    Color.clear
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .ignoresSafeArea(edges: .top)
                                .padding(.bottom, layout.tabBarHeight)
                                .accessibilityLabel("Dismiss more menu")

                                moreMenuCard(maxHeight: max(44, proxy.size.height - layout.bottomInset - proxy.safeAreaInsets.top - 12))
                                    .frame(width: layout.menuWidth)
                                    .padding(.trailing, layout.trailingInset)
                                    .padding(.bottom, layout.bottomInset)
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        .transition(.scale(scale: 0.92, anchor: UnitPoint(x: 0.86, y: 1)).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: showMoreMenu)
                .onAppear {
                    if compactPrimaryDestinations.contains(appState.selectedDestination) {
                        lastPrimaryDestination = appState.selectedDestination
                    }
                }
                .onChange(of: appState.selectedDestination) { old, newValue in
                    if newValue == .settings {
                        // Keep the page that was showing, and put Settings over it.
                        destinationBeforeSettings = old == .settings ? destinationBeforeSettings : old
                        appState.selectedDestination = destinationBeforeSettings
                        showingSettingsSheet = true
                        return
                    }
                    if compactPrimaryDestinations.contains(newValue) {
                        lastPrimaryDestination = newValue
                    }
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsStack(model: appState.settingsNavigation) {
                        SettingsView(presentation: .pushed)
                            .hubPageBackground()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showingSettingsSheet = false }
                                }
                            }
                    }
                    .environmentObject(appState)
                    .presentationDragIndicator(.visible)
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
                            // Settings is a grouped list, which sits on the grouped-list page color. Painted only
                            // behind the list it showed as a grey rectangle inset in the white page (with hard
                            // edges, and a 900 pt strip on a wide iPad), so the whole area takes the color.
                            .background {
                                if appState.selectedDestination == .settings {
                                    HubTheme.canvas.ignoresSafeArea(edges: [.bottom, .trailing])
                                }
                            }
                    }
                }
                .hubSurfaceBackground()
            }
        }
        .environment(\.openHubDestination) { destination in
            appState.selectedDestination = destination
        }
    }

    private var compactTabSelection: Binding<HubDestination> {
        Binding(
            get: {
                // While the menu is open the More tab is the selected one, like any other tab (and like Ivory); the page
                // behind it is a picture of the page you were on.
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
                    // Normally the tab bar hook has already handled this tap; without it, handle it here.
                    if moreTapHandled { moreTapHandled = false } else { showMoreMenu.toggle() }
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

    /// Pages made of people's colors get a neutral glow; the others get the theme's.
    private func wash(for destination: HubDestination) -> HubWash {
        switch destination {
        case .routines, .chores, .sleep: .neutral
        default: .theme
        }
    }

    @ViewBuilder
    private var moreTabContent: some View {
        if showMoreMenu, let snapshot = moreSnapshot, !compactOverflowDestinations.contains(appState.selectedDestination) {
            Image(uiImage: snapshot)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            compactMoreTab
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

    private var moreMenuRowHeight: CGFloat { moreMenuLineHeight + 24 }

    private func moreMenuCard(maxHeight: CGFloat) -> some View {
        ScrollView {
            moreMenuRows
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(maxHeight, CGFloat(compactOverflowDestinations.count) * moreMenuRowHeight + CGFloat(max(0, compactOverflowDestinations.count - 1))))
        .hubGlass(cornerRadius: 22)
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .accessibilityIdentifier("hub.moreMenu")
    }

    private var moreMenuRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(compactOverflowDestinations.reversed().enumerated()), id: \.element.id) { index, destination in
                Button {
                    appState.selectedDestination = destination
                    showMoreMenu = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: destination.systemImage)
                            .font(.body.weight(.semibold))
                            .frame(width: moreMenuIconWidth)
                        Text(destination.label)
                            .font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                    }
                    .foregroundStyle(
                        appState.selectedDestination == destination ? HubTheme.accentText : .primary
                    )
                    .padding(.horizontal, 14)
                    .frame(minHeight: moreMenuRowHeight)
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
        let menuWidth = min(proxy.size.width - 16, max(moreMenuWidth, min(188, max(156, tabWidth + 86))))
        let trailingInset = max(8, (tabWidth - menuWidth) / 2)
        return (menuWidth, trailingInset, max(10, tabBarHeight - 4), tabBarHeight)
    }

    private func compactPage(for destination: HubDestination) -> some View {
        content(for: destination)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The page's margin is a margin on what scrolls, not padding around the scroll view: a padded scroll
            // view is a box inside the page, clipped at its edges, instead of content that moves under the
            // status bar and the tab bar like every native page.
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.top, HubScreen.topInset + 14, for: .scrollContent)
            .contentMargins(.bottom, HubScreen.tabBarClearance + 14, for: .scrollContent)
            .hubFullBleed()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .hubSurfaceBackground()
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
    @ScaledMetric(relativeTo: .caption2) private var sidebarWidth = 104.0
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
                    name: appState.household?.name ?? "Tugboat",
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
        .frame(width: sidebarWidth)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
    @State private var confirmSignOut = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                householdHeading
                Spacer(minLength: 12)
                readouts
            }
            VStack(alignment: .leading, spacing: 10) {
                householdHeading
                readouts
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(minHeight: 78)
        .hubSurfaceBackground()
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
        .confirmationDialog("Sign Out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
        }
    }

    private var householdHeading: some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(appState.household?.name ?? "Tugboat")
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
    }

    private var readouts: some View {
        HStack(spacing: 12) {
            // Ambient readouts sit together on the trailing edge: temperature, then time.
            WeatherHeaderReadout()
            if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
                LiveClockView(timezone: timezone)
                    .padding(.leading, 4)
            }
            if let role = appState.household?.role, HouseholdRoles.isGuest(role: role) {
                Button("Sign Out") {
                    confirmSignOut = true
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
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

/// Lets a tap on the More tab open the menu without ever selecting the tab. Selecting it showed a second, fresh copy
/// of the current page behind the menu (scrolled to the top) and moved the highlight to More and back, which looked
/// like the app bouncing. The page you are on stays selected and the menu floats over it.
private struct MoreTabInterceptor: UIViewControllerRepresentable {
    let hasMoreTab: Bool
    let onMoreTapped: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> Finder { Finder() }

    func updateUIViewController(_ controller: Finder, context: Context) {
        controller.hasMoreTab = hasMoreTab
        controller.onMoreTapped = onMoreTapped
        controller.install()
    }

    final class Finder: UIViewController {
        var hasMoreTab = false
        var onMoreTapped: (UIImage?) -> Void = { _ in }
        private var proxy: Proxy?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        func install() {
            guard let tabBarController else { return }
            if let existing = proxy, tabBarController.delegate === existing { 
                existing.finder = self
                return
            }
            let proxy = Proxy(original: tabBarController.delegate, finder: self)
            self.proxy = proxy
            tabBarController.delegate = proxy
        }
    }

    final class Proxy: NSObject, UITabBarControllerDelegate {
        weak var original: UITabBarControllerDelegate?
        weak var finder: Finder?
        init(original: UITabBarControllerDelegate?, finder: Finder) {
            self.original = original
            self.finder = finder
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            if let finder, finder.hasMoreTab, viewController === tabBarController.viewControllers?.last {
                let leaving = tabBarController.selectedViewController
                finder.onMoreTapped(leaving === viewController ? nil : Proxy.picture(of: leaving?.view))
                return true
            }
            return original?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        /// iOS 18 and later ask this instead when the controller is built from tabs, which is how SwiftUI builds it
        /// on the newest systems; the question above is then never asked.
        @available(iOS 18.0, *)
        func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
            if let finder, finder.hasMoreTab, tab === tabBarController.tabs.last {
                let leaving = tabBarController.selectedTab
                finder.onMoreTapped(leaving === tab ? nil : Proxy.picture(of: leaving?.viewController?.view))
                return true
            }
            return original?.tabBarController?(tabBarController, shouldSelectTab: tab) ?? true
        }

        /// What a page looks like right now, tab bar not included.
        static func picture(of view: UIView?) -> UIImage? {
            guard let view, view.bounds.width > 0 else { return nil }
            return UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
        }

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
        }
        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            (original?.responds(to: aSelector) ?? false) ? original : super.forwardingTarget(for: aSelector)
        }
    }
}
