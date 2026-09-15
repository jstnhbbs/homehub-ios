import SwiftUI
import UIKit

struct HubView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showMoreMenu = false
    @State private var lastPrimaryDestination: HubDestination = .dashboard
    @State private var compactSettingsPath = NavigationPath()
    @State private var compactMealsPath = NavigationPath()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                TabView(selection: compactTabSelection) {
                    ForEach(compactPrimaryDestinations, id: \.rawValue) { destination in
                        compactTab(for: destination)
                            .id("tab-\(compactTabLayoutID)-\(destination.rawValue)")
                            .tabItem {
                                Label(destination.label, systemImage: destination.systemImage)
                                    .id("tab-item-\(compactTabLayoutID)-\(destination.rawValue)")
                            }
                            .tag(destination)
                    }
                    if !compactOverflowDestinations.isEmpty {
                        compactMoreTab
                            .id("tab-\(compactTabLayoutID)-\(HubDestination.more.rawValue)")
                            .tabItem {
                                Label(HubDestination.more.label, systemImage: HubDestination.more.systemImage)
                                    .id("tab-item-\(compactTabLayoutID)-\(HubDestination.more.rawValue)")
                            }
                            .tag(HubDestination.more)
                    }
                }
                .id(compactTabLayoutID)
                .tint(HubTheme.sage)
                .background(HubTheme.surface)
                .background {
                    if !compactOverflowDestinations.isEmpty {
                        MoreTabReselectMonitor {
                            showMoreMenu.toggle()
                        }
                    }
                }
                .overlay {
                    if showMoreMenu {
                        GeometryReader { proxy in
                            let layout = moreMenuLayout(in: proxy)

                            ZStack(alignment: .bottomTrailing) {
                                Color.black.opacity(0.16)
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
                        .transition(.scale(scale: 0.84, anchor: UnitPoint(x: 0.92, y: 1)).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.22), value: showMoreMenu)
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
                    HubNavView()
                    VStack(spacing: 0) {
                        HubHeaderView()
                        content(for: appState.selectedDestination)
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
            NavigationStack(path: $compactSettingsPath) {
                SettingsView(presentation: .tabRoot)
            }
        } else if destination == .meals {
            NavigationStack(path: $compactMealsPath) {
                compactPage(for: destination)
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
        let destinations = Array(compactOverflowDestinations.reversed())
        return VStack(spacing: 0) {
            ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
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
                        Spacer(minLength: 4)
                    }
                    .foregroundStyle(
                        appState.selectedDestination == destination ? HubTheme.sage : .primary
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(appState.selectedDestination == destination ? .isSelected : [])

                if index < destinations.count - 1 {
                    Rectangle()
                        .fill(HubTheme.line.opacity(0.55))
                        .frame(height: 1)
                        .padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
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
        let menuWidth: CGFloat = min(176, max(148, tabWidth + 72))
        let trailingInset = max(6, (tabWidth - menuWidth) / 2)
        let tabBarHeight: CGFloat = 49
        let gap: CGFloat = 8
        let safeBottom = proxy.safeAreaInsets.bottom
        let tabBarOffset = safeBottom > tabBarHeight ? safeBottom : safeBottom + tabBarHeight
        return (menuWidth, trailingInset, tabBarOffset + gap, tabBarOffset)
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

    private var items: [HubDestination] {
        let ordered = appState.hubModules.sidebarOrder.compactMap { HubDestination(module: $0) }
        return ([.dashboard] + ordered).filter { destination in
            destination.isVisible(in: appState.hubModules)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let parentItems = appState.canManageHousehold ? [HubDestination.settings] : []
            let availableSlots = max(2, Int((proxy.size.height - 128 - CGFloat(parentItems.count * 76)) / 76))
            let primaryItems = Array(items.prefix(availableSlots))
            let overflowItems = Array(items.dropFirst(availableSlots))

            VStack(spacing: 8) {
                HouseholdMarkView(
                    name: appState.household?.name ?? "Beacon",
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
                        .foregroundStyle(HubTheme.muted)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                ForEach(parentItems) { destination in
                    sidebarButton(destination)
                }
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
}

struct HubHeaderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(appState.household?.name ?? "Beacon")
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
        case .profile:
            MyProfileView()
        case .settings:
            SettingsView(presentation: presentation)
        case .more:
            EmptyView()
        }
    }
}

private final class WindowAwareView: UIView {
    var onMovedToWindow: ((UIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        onMovedToWindow?(self)
    }
}

private struct MoreTabReselectMonitor: UIViewRepresentable {
    var onReselect: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselect: onReselect)
    }

    func makeUIView(context: Context) -> WindowAwareView {
        let view = WindowAwareView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onMovedToWindow = { [weak coordinator = context.coordinator] hosted in
            coordinator?.attach(from: hosted)
        }
        return view
    }

    func updateUIView(_ uiView: WindowAwareView, context: Context) {
        context.coordinator.onReselect = onReselect
        uiView.onMovedToWindow = { [weak coordinator = context.coordinator] hosted in
            coordinator?.attach(from: hosted)
        }
        if uiView.window != nil {
            context.coordinator.attach(from: uiView)
        }
    }

    final class Coordinator: NSObject {
        var onReselect: () -> Void
        private var recognizer: UITapGestureRecognizer?
        private weak var button: UIView?

        init(onReselect: @escaping () -> Void) {
            self.onReselect = onReselect
        }

        func attach(from view: UIView) {
            guard view.window != nil, let tabBar = Self.findTabBar(from: view) else { return }
            let buttons = tabBar.subviews
                .filter { String(describing: type(of: $0)).contains("TabBarButton") }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard let moreButton = buttons.last else { return }
            if button === moreButton, recognizer != nil { return }

            if let recognizer {
                button?.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            moreButton.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
            button = moreButton
        }

        @objc private func handleTap() {
            guard let tabBar = button?.superview as? UITabBar,
                  let items = tabBar.items,
                  tabBar.selectedItem === items.last else {
                return
            }
            onReselect()
        }

        private static func findTabBar(from view: UIView) -> UITabBar? {
            var responder: UIResponder? = view
            while let current = responder {
                if let tabController = current as? UITabBarController {
                    return tabController.tabBar
                }
                responder = current.next
            }
            return findTabBarController(from: view.window?.rootViewController)?.tabBar
        }

        private static func findTabBarController(from controller: UIViewController?) -> UITabBarController? {
            guard let controller else { return nil }

            if let tabController = controller as? UITabBarController {
                return tabController
            }
            for child in controller.children {
                if let found = findTabBarController(from: child) {
                    return found
                }
            }
            guard let presentedController = controller.presentedViewController else {
                return nil
            }
            return findTabBarController(from: presentedController)
        }
    }
}
