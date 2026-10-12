import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private static let gridMinimumWidth: CGFloat = 520
    @State private var compactNavigationPath = NavigationPath()
    /// Rearranging the cards on the page itself (edit mode); see DashboardEditing.swift.
    @StateObject private var edit = DashboardEditState()
    @State private var layoutSaveTask: Task<Void, Never>?
    /// The moment the day-dependent parts (header date, birthday banner) were last drawn for. It is
    /// only replaced when the day changes, so the banner appears and goes away at midnight on its own
    /// without redrawing the whole dashboard every minute.
    @State private var clock = Date()
    // Greeting keeps its size-class-dependent sizes, now scaled for Dynamic Type.
    @ScaledMetric(relativeTo: .title) private var greetingCompactSize: CGFloat = 26
    @ScaledMetric(relativeTo: .title) private var greetingRegularSize: CGFloat = 32

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack(path: $compactNavigationPath) {
                    compactDashboardContent
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    .hubPageBackground()
                    .navigationTitle("Today")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HubDestination.self) { destination in
                        compactDestinationPage(destination)
                            .hubPageBackground()
                    }
                }
                .environment(\.openHubDestination) { destination in
                    openDestination(destination)
                }
            } else {
                GeometryReader { proxy in
                    // Under this width the page is a single column of fixed-height cards; above it, the real
                    // grid. 520 lets an iPad mini in portrait (about 550pt of page beside the sidebar) have two
                    // columns and honour each card's Standard/Expanded size, as larger iPads do.
                    let isCompact = proxy.size.width < Self.gridMinimumWidth
                    let cards = arranged(dashboardCards(for: .tablet))
                    let layout = DashboardCardLayout(
                        cards: cards,
                        cardSizes: appState.hubModules.dashboardCardSizes(for: .tablet),
                        availableSize: proxy.size,
                        isCompact: isCompact,
                        usesFlexibleMacLayout: isRunningAsIPadAppOnMac,
                        usesAccessibilityLayout: DashboardMetrics.usesAccessibilityLayout(dynamicTypeSize)
                    )
                    let contentMaxWidth: CGFloat? = isRunningAsIPadAppOnMac ? nil : 1_500
                    dashboardContent(cards: cards, layout: layout, isCompact: isCompact)
                        .frame(maxWidth: contentMaxWidth, maxHeight: .infinity, alignment: .topLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .overlay(alignment: .bottomTrailing) {
                            // The narrow single-column fallback keeps its fixed cards; it is edited in Settings.
                            if !isCompact, appState.dashboard != nil {
                                DashboardEditButton(isEditing: edit.isEditing, action: toggleEditing)
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 4)
                            }
                        }
                }
            }
        }
        .frame(minHeight: 480)
        .refreshable {
            await appState.refreshDashboard(forcingDeviceRefresh: true)
        }
        .task {
            if appState.dashboard == nil {
                await appState.refreshDashboard()
            } else {
                await appState.refreshNativeTodaySchedule()
            }
        }
        .onTick(every: 60) {
            let now = Date()
            if dayChanged(from: clock, to: now) { clock = now }
        }
    }

    /// True when `new` is a different day from `old` on the device's calendar or in the household's
    /// time zone, which is what the birthday banner uses.
    private func dayChanged(from old: Date, to new: Date) -> Bool {
        if !Calendar.current.isDate(old, inSameDayAs: new) { return true }
        guard let id = appState.dashboard?.household.timezone, let timezone = TimeZone(identifier: id) else {
            return false
        }
        return DateHelpers.localDateIn(timezone: timezone, date: old) != DateHelpers.localDateIn(timezone: timezone, date: new)
    }

    @ViewBuilder
    private var compactDashboardContent: some View {
        if let dashboard = appState.dashboard {
            let cards = dashboardCards(for: .phone)
            let todaysBirthdays = birthdaysToday(dashboard)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    compactHeader(dashboard: dashboard)

                    if !todaysBirthdays.items.isEmpty {
                        BirthdayTodayBanners(items: todaysBirthdays.items, localDate: todaysBirthdays.localDate)
                    }

                    if cards.isEmpty {
                        ContentUnavailableView(
                            "No Today Cards",
                            systemImage: "rectangle.3.group",
                            description: Text("Turn cards back on in Settings.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        CompactNextUpPanel(
                            dashboard: dashboard,
                            enabledCards: cards,
                            onNavigate: openDestination
                        )

                        // One layout places the tiles: half-width tiles pair up, full-width ones take a row,
                        // and a Large tile is a full row twice as tall. At the largest text sizes a
                        // half-width tile cannot hold its text, so every tile takes the full width,
                        // whatever size was chosen for it in Settings.
                        let cardSizes: [DashboardCardId: DashboardCardSize] = DashboardMetrics.usesAccessibilityLayout(dynamicTypeSize)
                            ? Dictionary(uniqueKeysWithValues: DashboardCardId.allCases.map { ($0, DashboardCardSize.medium) })
                            : appState.hubModules.dashboardCardSizes(for: .phone)
                        let tileCards = arranged(edit.isEditing ? cards : compactGridCards(cards, dashboard: dashboard))
                        let tileItems = Dictionary(uniqueKeysWithValues: tileCards.map { card -> (DashboardCardId, DashboardFlowLayout.Item) in
                            let size = card.clamped(cardSizes[card, default: .small])
                            let isFull = size != .small
                            return (card, .init(isFull: isFull, fixedHeight: phoneCellHeight * CGFloat(size.rows) + 12 * CGFloat(size.rows - 1)))
                        })
                        DashboardFlowLayout(
                            items: tileItems,
                            frames: edit.frames
                        ) {
                            ForEach(tileCards) { card in
                                let size = card.clamped(cardSizes[card, default: .small])
                                dashboardCard(card, size: size, dashboard: dashboard)
                                .dashboardEditable(
                                    card: card,
                                    size: size,
                                    cornerRadius: card.usesTodayCard ? TodayCardFrame<EmptyView>.cornerRadius : 18,
                                    isEditing: edit.isEditing,
                                    isDragging: edit.draggingCard == card,
                                    drag: edit.drag,
                                    dragSpace: edit.probe,
                                    onDragChanged: { edit.dragChanged(card, locationInGrid: $0, order: tileCards) },
                                    onDragEnded: endDrag,
                                    onSetSize: { setSize(card, $0) },
                                    onRemove: { setEnabled(card, false) },
                                    onMove: { move(card, by: $0, within: tileCards) }
                                )
                                .layoutValue(key: DashboardCardKey.self, value: card)
                            }
                        }
                        .background(DashboardGridProbe(reference: edit.probe, isEditing: edit.isEditing, onPressAndHold: { edit.enter() }))

                        if edit.isEditing {
                            DashboardAddCardsTray(cards: TodayLayoutEditing.addableCards(in: appState.hubModules), onAdd: { setEnabled($0, true) })
                        }
                    }
                }
                .padding(.bottom, 64)
                // Room for the minus badges, which sit half outside their tiles (see the iPad grid).
                .padding(.horizontal, edit.isEditing ? 8 : 0)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottomTrailing) {
                DashboardEditButton(isEditing: edit.isEditing, action: toggleEditing)
                    .padding(.trailing, 2)
                    .padding(.bottom, 4)
            }
        } else if let errorMessage = appState.errorMessage {
            DashboardErrorView(message: errorMessage) {
                await appState.refreshDashboard()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading today")
        }
    }

    /// Schedule is folded into the Next Up hero, and an empty birthdays tile ("0 upcoming")
    /// is not worth a grid slot, so it drops out until there's something to show.
    private func compactGridCards(_ cards: [DashboardCardId], dashboard: DashboardData) -> [DashboardCardId] {
        cards.filter { card in
            switch card {
            // An empty birthdays tile is pure noise on a dense screen.
            case .birthdays: return !dashboard.upcomingBirthdays.isEmpty
            default: return true
            }
        }
    }

    private func compactHeader(dashboard: DashboardData) -> some View {
        HStack(spacing: 12) {
            HouseholdMarkView(
                name: dashboard.household.name,
                photo: dashboard.household.photo,
                ownerName: dashboard.household.ownerName,
                size: 42
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(clock.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Today")
                    .font(.title2.weight(.bold))
            }
            // Combine scoped to the title block: the weather readout is separately
            // focusable, and can be a button when location hasn't been granted.
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            WeatherHeaderReadout()
        }
    }

    /// Birthdays that fall today in the household's time zone, if the Birthdays module is on.
    private func birthdaysToday(_ dashboard: DashboardData) -> (items: [BirthdayItem], localDate: String) {
        let timezone = TimeZone(identifier: dashboard.household.timezone) ?? .current
        let today = DateHelpers.localDateIn(timezone: timezone, date: clock)
        guard appState.hubModules.isEnabled(.birthdays) else { return ([], today) }
        return (BirthdayToday.items(dashboard.upcomingBirthdays, today: today), today)
    }

    private var isRunningAsIPadAppOnMac: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac
    }

    private func openDestination(_ destination: HubDestination) {
        if horizontalSizeClass == .compact {
            if destination == .dashboard {
                compactNavigationPath = NavigationPath()
            } else {
                compactNavigationPath.append(destination)
            }
        } else {
            appState.selectedDestination = destination
        }
    }

    @ViewBuilder
    private func compactDestinationPage(_ destination: HubDestination) -> some View {
        HubDestinationContent(
            destination: destination,
            presentation: destination == .settings ? .pushed : .split
        )
        .padding(.horizontal, destination == .settings ? 0 : 16)
        .padding(.vertical, destination == .settings ? 0 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HubTheme.surface)
        .navigationTitle(destination.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    @ViewBuilder
    private func dashboardContent(
        cards: [DashboardCardId],
        layout: DashboardCardLayout,
        isCompact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let dashboard = appState.dashboard {
                let todaysBirthdays = birthdaysToday(dashboard)

                if !todaysBirthdays.items.isEmpty {
                    BirthdayTodayBanners(items: todaysBirthdays.items, localDate: todaysBirthdays.localDate)
                }

                if edit.isEditing {
                    Text("Drag a card to move it. Use its size button to pick a size, or the minus to take it off.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .transition(.opacity)
                }

                if cards.isEmpty && !edit.isEditing {
                    ContentUnavailableView(
                        "No Today Cards",
                        systemImage: "rectangle.3.group",
                        description: Text("Tap the pencil to add cards back.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if isCompact {
                                VStack(spacing: 16) {
                                    ForEach(cards) { card in
                                        dashboardCard(
                                            card,
                                            size: card.clamped(layout.cardSizes[card, default: .small]),
                                            dashboard: dashboard,
                                            fixedHeight: layout.height(for: card)
                                        )
                                    }
                                }
                            } else {
                                let packing = layout.packing
                                DashboardGridLayout(
                                    placements: Dictionary(uniqueKeysWithValues: packing.placements.map { ($0.card, $0) }),
                                    columnCount: layout.columnCount,
                                    rowCount: packing.rowCount,
                                    rowHeight: layout.rowHeight,
                                    spacing: 16,
                                    frames: edit.frames
                                ) {
                                    ForEach(cards) { card in
                                        let size = card.clamped(layout.cardSizes[card, default: .small])
                                        dashboardCard(card, size: size, dashboard: dashboard)
                                        .dashboardEditable(
                                            card: card,
                                            size: size,
                                            cornerRadius: card.usesTodayCard ? TodayCardFrame<EmptyView>.cornerRadius : 24,
                                            isEditing: edit.isEditing,
                                            isDragging: edit.draggingCard == card,
                                            drag: edit.drag,
                                            dragSpace: edit.probe,
                                            onDragChanged: { edit.dragChanged(card, locationInGrid: $0, order: cards) },
                                            onDragEnded: endDrag,
                                            onSetSize: { setSize(card, $0) },
                                            onRemove: { setEnabled(card, false) },
                                            onMove: { move(card, by: $0, within: cards) }
                                        )
                                        .layoutValue(key: DashboardCardKey.self, value: card)
                                    }
                                }
                                .background(DashboardGridProbe(reference: edit.probe, isEditing: edit.isEditing, onPressAndHold: { edit.enter() }))
                            }

                            if edit.isEditing {
                                DashboardAddCardsTray(
                                    cards: TodayLayoutEditing.addableCards(in: appState.hubModules),
                                    onAdd: { setEnabled($0, true) }
                                )
                                .padding(.bottom, 72)
                            }
                        }
                        // The minus badges sit half outside their cards, so the grid steps in a little
                        // while editing (to the side and from the top) rather than have the scroll view cut
                        // them off; the first row's badges were clipped at the top edge.
                        .padding(.horizontal, edit.isEditing ? 10 : 0)
                        .padding(.top, edit.isEditing ? 14 : 0)
                    }
                    .scrollIndicators(.hidden)
                }
            } else if let errorMessage = appState.errorMessage {
                DashboardErrorView(message: errorMessage) {
                    await appState.refreshDashboard()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading today…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// One grid cell's height on the iPhone for the shared card; a Large card is two of them.
    private var phoneCellHeight: CGFloat { DashboardMetrics.scaled(168, .body) }

    // MARK: Editing the layout on the page

    private var layoutTarget: DashboardLayoutTarget {
        horizontalSizeClass == .compact ? .phone : .tablet
    }

    /// `base` in the order the cards are being dragged into, while a drag is under way.
    private func arranged(_ base: [DashboardCardId]) -> [DashboardCardId] {
        guard let preview = edit.previewOrder else { return base }
        let known = Set(base)
        var result = preview.filter(known.contains)
        result.append(contentsOf: base.filter { !result.contains($0) })
        return result
    }

    private func toggleEditing() {
        if edit.isEditing { edit.exit() } else { edit.enter() }
    }

    /// Applies and saves a layout change right away, like every other switch in Settings.
    private func commitLayout(_ next: HubModules) {
        guard next != appState.hubModules else { return }
        appState.applyHubModules(next)
        layoutSaveTask?.cancel()
        layoutSaveTask = Task { await appState.saveHubModules(next) }
    }

    private func setSize(_ card: DashboardCardId, _ requested: DashboardCardSize) {
        let modules = appState.hubModules
        let size = card.clamped(requested)
        guard size != modules.dashboardCardSize(card, for: layoutTarget) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.2)) {
            commitLayout(modules.updatingDashboardCardSize(card, size: size, for: layoutTarget))
        }
    }

    private func setEnabled(_ card: DashboardCardId, _ enabled: Bool) {
        withAnimation(.snappy(duration: 0.2)) {
            commitLayout(appState.hubModules.updatingDashboardCard(card, enabled: enabled))
        }
    }

    /// The Move earlier and Move later actions, for VoiceOver and Switch Control.
    private func move(_ card: DashboardCardId, by offset: Int, within visible: [DashboardCardId]) {
        let next = TodayLayoutEditing.moving(card, by: offset, in: visible)
        guard next != visible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            commitLayout(appState.hubModules.arrangingDashboardCards(next, for: layoutTarget))
        }
    }

    private func endDrag() {
        if let final = edit.dragEnded() {
            withAnimation(.snappy(duration: 0.2)) {
                commitLayout(appState.hubModules.arrangingDashboardCards(final, for: layoutTarget))
            }
        }
        edit.finishCommit()
    }

    private func dashboardCards(for target: DashboardLayoutTarget) -> [DashboardCardId] {
        appState.hubModules.dashboardOrder(for: target).filter { card in
            // Weather is ambient with no destination and no actions, so it renders in
            // the header rather than consuming a tile. Its toggle still gates it there.
            card != .weather && appState.hubModules.isDashboardCardEnabled(card)
        }
    }

    /// The card for `card` at `size`, the same on iPhone and iPad. `fixedHeight` is for the one place with no
    /// grid to size it (the narrow single-column iPad layout).
    @ViewBuilder
    private func dashboardCard(
        _ card: DashboardCardId,
        size: DashboardCardSize,
        dashboard: DashboardData,
        fixedHeight: CGFloat? = nil
    ) -> some View {
        switch card {
        case .weather:
            // Weather renders in the header, never as a card. `dashboardCards` filters it out upstream;
            // this case only exists for exhaustiveness.
            EmptyView()
        case .schedule: ScheduleTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .routines: RoutinesTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .chores: ChoresTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .meals: FoodTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .snacks: SnacksTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .sleep: SleepTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .groceries: GroceriesTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .notes: NotesTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        case .birthdays: CelebrationsTodayCard(dashboard: dashboard, size: size, fixedHeight: fixedHeight)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if horizontalSizeClass == .compact {
                HouseholdMarkView(
                    name: appState.household?.name ?? "Tugboat",
                    photo: appState.household?.photo,
                    ownerName: appState.household?.ownerName,
                    size: 44
                )
            }
            Text("Here's what's happening today.")
                .font(.system(
                    size: horizontalSizeClass == .compact ? greetingCompactSize : greetingRegularSize,
                    weight: .semibold,
                    design: .rounded
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The next thing with a time on it, across calendar events and chores (see `NextUpSummary`), at the top of
/// Today on iPhone. When nothing has a time the banner doesn't appear at all rather than spend space saying
/// so. Routines have no times, so they are not here; the Routines card says what is next for them.
private struct CompactNextUpPanel: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData
    let enabledCards: [DashboardCardId]
    let onNavigate: (HubDestination) -> Void

    @State private var now = Date.now

    private var item: NextUpItem? {
        NextUpSummary.next(
            chores: enabledCards.contains(.chores) ? dashboard.chores : [],
            events: enabledCards.contains(.schedule) && appState.nativeCalendar.hasFullAccess ? appState.nativeTodayScheduleEvents : [],
            profiles: dashboard.profiles,
            todayDate: dashboard.localDate,
            timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current,
            now: now
        )
    }

    var body: some View {
        if let item {
            Button {
                onNavigate(item.kind == .event ? .calendar : .chores)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.kind == .event ? "calendar" : "checkmark.square.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HubTheme.accentText)
                        .frame(width: 38, height: 38)
                        .background(HubTheme.sage.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.eyebrow)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.accentText)
                        Text(item.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(item.detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HubTheme.tile)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HubTheme.sage.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onTick(every: 60) { now = Date() }
        }
    }
}

// MARK: - Compact tile building blocks

/// Shared failure handling for one-tap completions: the check animates back off
/// when the call throws, and the failure is reported so it is not silent. Main-actor because
/// `report` publishes to the app state, which must happen on the main thread.
@MainActor
private func compactCompletion(report: (Error) -> Void, _ work: () async throws -> Void) async -> Bool {
    do {
        try await work()
        return true
    } catch {
        report(error)
        return false
    }
}

private struct DashboardErrorView: View {
    let message: String
    let retry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Today could not load", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.red)

                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)

                Button {
                    Task {
                        guard !isRetrying else { return }
                        isRetrying = true
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    Label(isRetrying ? "Retrying" : "Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                .disabled(isRetrying)
            }
        }
        .frame(maxWidth: 520)
    }
}


// MARK: - Layout primitives

private struct DashboardCardLayout {
    let cards: [DashboardCardId]
    let cardSizes: [DashboardCardId: DashboardCardSize]
    let availableSize: CGSize
    let isCompact: Bool
    let usesFlexibleMacLayout: Bool
    /// The very largest text sizes: one card per row, since half a screen cannot hold the text.
    var usesAccessibilityLayout = false

    private var spacing: CGFloat { 16 }
    /// Room under the cards for the edit button, so it never sits over a card.
    private var bottomReserve: CGFloat { isCompact ? 0 : 56 }
    private var contentWidth: CGFloat {
        guard !isCompact else { return max(0, availableSize.width - 32) }
        return usesFlexibleMacLayout ? availableSize.width : min(availableSize.width, 1_500)
    }

    /// Every card with the size it takes on this grid (a size the card doesn't offer is brought back
    /// to one it does).
    var items: [DashboardGridItem] {
        cards.map { card in
            let size = card.clamped(cardSizes[card, default: .small])
            return DashboardGridItem(card: card, columns: size.columns, rows: size.rows)
        }
    }

    private var widthCap: Int {
        guard !isCompact, !usesAccessibilityLayout else { return 1 }
        if usesFlexibleMacLayout {
            let minimumColumnWidth: CGFloat = 250
            let columnsByWidth = Int(floor((contentWidth + spacing) / (minimumColumnWidth + spacing)))
            return min(6, max(2, columnsByWidth))
        }
        if availableSize.width >= 1_060 { return 4 }
        if availableSize.width >= 720 { return 3 }
        return 2
    }

    /// The grid's width in cells. The page's height matters too: the grid is sized to fill the screen,
    /// so the count is the one that leaves the cards the best shape.
    var columnCount: Int {
        DashboardGridPacker.columnCount(
            widthCap: widthCap,
            items: items,
            size: CGSize(width: contentWidth, height: max(360, availableSize.height - 72 - bottomReserve)),
            spacing: spacing
        )
    }

    var packing: DashboardGridPacker.Result {
        DashboardGridPacker.pack(items, columnCount: columnCount)
    }

    /// The height of one grid row. A card's own title and padding grow with the text, so its smallest
    /// height does too.
    var rowHeight: CGFloat {
        guard !isCompact else { return DashboardMetrics.scaled(300, .body) }

        let rows = max(1, packing.rowCount)
        let rowSpacing = CGFloat(rows - 1) * spacing
        let availableHeight = max(360, availableSize.height - 72 - bottomReserve - rowSpacing)
        return max(DashboardMetrics.scaled(170, .body), floor(availableHeight / CGFloat(rows)))
    }

    /// How tall a card of this size is: its rows and the gaps between them.
    func height(for card: DashboardCardId) -> CGFloat {
        let rows = CGFloat(items.first { $0.card == card }?.rows ?? 1)
        return rowHeight * rows + spacing * (rows - 1)
    }
}

/// Places each card at the cells the packer gave it. Used for the iPad and Mac grid, where every row
/// is the same height and a Large card is exactly two rows tall.
private struct DashboardGridLayout: Layout {
    let placements: [DashboardCardId: DashboardGridPlacement]
    let columnCount: Int
    let rowCount: Int
    let rowHeight: CGFloat
    let spacing: CGFloat
    /// Told where each card's cell is, so a drag can find the card under the finger.
    let frames: DashboardFrameStore

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = CGFloat(max(1, rowCount))
        return CGSize(
            width: proposal.width ?? 600,
            height: rowHeight * rows + spacing * (rows - 1)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = CGFloat(max(1, columnCount))
        let columnWidth = max(0, (bounds.width - spacing * (columns - 1)) / columns)
        var cells: [DashboardCardId: CGRect] = [:]
        for subview in subviews {
            guard let card = subview[DashboardCardKey.self], let placement = placements[card] else { continue }
            let width = columnWidth * CGFloat(placement.columns) + spacing * CGFloat(placement.columns - 1)
            let height = rowHeight * CGFloat(placement.rows) + spacing * CGFloat(placement.rows - 1)
            let cell = CGRect(
                x: CGFloat(placement.column) * (columnWidth + spacing),
                y: CGFloat(placement.row) * (rowHeight + spacing),
                width: width,
                height: height
            )
            cells[card] = cell
            // A card being dragged says where the finger has it (see DashboardDragOriginKey).
            let origin = subview[DashboardDragOriginKey.self] ?? cell.origin
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
        frames.frames = cells
    }
}

private struct DashboardCardKey: LayoutValueKey {
    static let defaultValue: DashboardCardId? = nil
}

/// Places the iPhone's tiles: half-width tiles pair up, full-width tiles take a row, and every row is
/// as tall as its tallest tile (a Large tile is at least two tiles tall). Like the iPad grid it tells
/// `frames` where each tile is, and draws a dragged tile where the finger has it.
private struct DashboardFlowLayout: Layout {
    struct Item {
        var isFull: Bool
        /// A card has exactly this height (its cells), whatever it holds.
        var fixedHeight: CGFloat
    }

    let items: [DashboardCardId: Item]
    let frames: DashboardFrameStore

    private let columnSpacing: CGFloat = 10
    private let rowSpacing: CGFloat = 12

    private struct Row {
        var indices: [Int]
        var height: CGFloat
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        let half = max(0, (width - columnSpacing) / 2)
        func height(_ index: Int, _ width: CGFloat) -> CGFloat {
            subviews[index][DashboardCardKey.self].flatMap { items[$0]?.fixedHeight } ?? 0
        }
        var rows: [Row] = []
        var pending: Int?
        for index in subviews.indices {
            let isFull = subviews[index][DashboardCardKey.self].flatMap { items[$0]?.isFull } ?? false
            if isFull {
                if let waiting = pending {
                    rows.append(Row(indices: [waiting], height: height(waiting, half)))
                    pending = nil
                }
                rows.append(Row(indices: [index], height: height(index, width)))
            } else if let waiting = pending {
                rows.append(Row(indices: [waiting, index], height: max(height(waiting, half), height(index, half))))
                pending = nil
            } else {
                pending = index
            }
        }
        if let waiting = pending {
            rows.append(Row(indices: [waiting], height: height(waiting, half)))
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let rows = rows(width: width, subviews: subviews)
        let total = rows.reduce(CGFloat(0)) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let half = max(0, (bounds.width - columnSpacing) / 2)
        var cells: [DashboardCardId: CGRect] = [:]
        var y: CGFloat = 0
        for row in rows(width: bounds.width, subviews: subviews) {
            for (position, index) in row.indices.enumerated() {
                let subview = subviews[index]
                let isFull = subview[DashboardCardKey.self].flatMap { items[$0]?.isFull } ?? false
                let width = isFull ? bounds.width : half
                let cell = CGRect(x: position == 0 ? 0 : half + columnSpacing, y: y, width: width, height: row.height)
                let card = subview[DashboardCardKey.self]
                if let card { cells[card] = cell }
                let origin = subview[DashboardDragOriginKey.self] ?? cell.origin
                subview.place(
                    at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: row.height)
                )
            }
            y += row.height + rowSpacing
        }
        frames.frames = cells
    }
}

/// A flame and a day count, shown next to a child's routine progress.
struct StreakChip: View {
    let days: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.caption2.weight(.bold))
            Text("\(days)")
                .font(.caption.weight(.heavy))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.14))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StreakHelpers.label(days))
    }
}


// MARK: - Schedule

struct ScheduleEventRow: View {
    let event: ScheduleEvent
    let timezone: TimeZone
    var showsCalendarName = true

    var body: some View {
        DashboardRow(title: event.title, subtitle: subtitle) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(HubTheme.profileColor(event.color))
                .frame(width: 5, height: 28)
        } trailing: {
            EmptyView()
        }
    }

    private var subtitle: String {
        let time = event.allDay
            ? "All day"
            : DateHelpers.timeString(event.startsAt, timezone: timezone)
        if showsCalendarName, let calendarName = event.calendarName {
            return "\(time) · \(calendarName)"
        }
        return time
    }
}

// MARK: - Meals

struct MealTile: Identifiable {
    let slot: MealSlot
    let meal: Meal?
    var id: MealSlot { slot }
}

struct MealSlotRow: View {
    let slot: MealSlot
    let meal: Meal?

    private static let maxLines = 3

    /// Height a slot needs: padding, the slot label, then up to three lines. The first line
    /// (the dish name) may wrap to two, the rest stay on one.
    static func height(for meal: Meal?, columnWidth: CGFloat) -> CGFloat {
        let lines = Array(DashboardHelpers.mealLines(meal?.title ?? "").prefix(maxLines))
        let count = max(1, lines.count)
        let firstLineCount = DashboardRowHelpers.estimatedLineCount(
            characterCount: lines.first?.count ?? 0,
            availableWidth: columnWidth - 24,
            averageCharacterWidth: DashboardMetrics.scaled(9),
            maxLines: 2
        )
        let textLines = firstLineCount + (count - 1)
        return 24 + DashboardMetrics.scaled(13, .caption2) + 4 + CGFloat(textLines) * DashboardMetrics.scaled(20) + CGFloat(count - 1) * 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(slot.label.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)

            let lines = Array(DashboardHelpers.mealLines(meal?.title ?? "").prefix(Self.maxLines))
            if lines.isEmpty {
                Text("Not planned")
                    .font(.subheadline.weight(.semibold))
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(index == 0 ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundStyle(index == 0 ? Color.primary : HubTheme.muted)
                        .lineLimit(index == 0 ? 2 : 1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Snacks

struct DashboardSleepRow: View {
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
        DashboardRow(title: profile.name, subtitle: statusText(for: status)) {
            ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color, size: 28)
        } trailing: {
            if let activeLogId = status.activeLogId {
                Button(status.state == .inBed ? "Wake Up" : "End") { end(activeLogId) }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .mini))
            }
        }
    }

    private func end(_ logId: String) {
        Task {
            do {
                try await appState.api.endNap(napId: logId)
                await appState.refreshDashboard()
            } catch {
                appState.report(error)
            }
        }
    }

    private func statusText(for status: ChildDashboardSleepStatus) -> String {
        let duration = NapHelpers.formatDuration(minutes: status.durationMinutes)
        switch status.state {
        case .napping: return "Nap · asleep \(duration)"
        case .inBed:
            let started = DateHelpers.timeString(status.startedAt ?? now, timezone: timezone)
            return "In bed since \(started) · \(duration)"
        case .awake: return "Awake \(duration)"
        case .empty: return "No sleep logged today"
        }
    }
}

struct SnackListItem: Identifiable {
    let label: String
    var id: String { label }
}

struct NoteRow: View {
    let note: HouseholdNote
    let canDelete: Bool
    let isDeleting: Bool
    let onDelete: () async -> Void

    var body: some View {
        DashboardRow(title: note.title, subtitle: note.body.isEmpty ? nil : note.body) {
            Image(systemName: note.pinned ? "pin.fill" : "note.text")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.accentText)
                .frame(width: 28, height: 28)
                .background(HubTheme.sage.opacity(0.12))
                .clipShape(Circle())
        } trailing: {
            if canDelete {
                Button {
                    Task { await onDelete() }
                } label: {
                    Image(systemName: isDeleting ? "hourglass" : "xmark")
                        .font(.caption.weight(.bold))
                        // A full-size touch target around the small icon.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(HubTheme.muted)
                .disabled(isDeleting)
                .accessibilityLabel("Delete Note")
            }
        }
    }
}

// MARK: - Check rows

/// Who a chore is for, as a row shows them: a short name and their color.
struct ChorePersonMark {
    let name: String
    let color: Color?
}

struct ChoreCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let chore: ChoreRow
    /// Nil when every chore on the card is for the same person, so the name isn't repeated on each row.
    let person: ChorePersonMark?
    @State private var isChecked: Bool
    @State private var isWorking = false
    @State private var isHidden = false

    init(chore: ChoreRow, person: ChorePersonMark?) {
        self.chore = chore
        self.person = person
        _isChecked = State(initialValue: chore.completed)
    }

    /// Who it is for and, when it has one, the time it is due ("Overdue" once that has passed).
    private var subtitle: String? {
        var parts: [String] = []
        if let person { parts.append(person.name) }
        // A late chore says so; its time has gone, so it adds only length (and in a narrow row, the cut-off
        // that hides the word that matters).
        if chore.overdue == true, !isChecked {
            parts.append("Overdue")
        } else if let time = chore.dueTime {
            parts.append(ChoreHelpers.timeLabel(time))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        if !isHidden {
            Button {
                Task { await toggle() }
            } label: {
                DashboardRow(
                    title: chore.title,
                    subtitle: subtitle,
                    subtitlePersonColor: person?.color,
                    isDone: isChecked
                ) {
                    DashboardCheckMarker(isChecked: isChecked)
                } trailing: {
                    if isWorking { ProgressView().controlSize(.small) }
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityValue(isChecked ? "Done" : "Not done")
            .accessibilityAddTraits(.isToggle)
        }
    }

    private func toggle() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.toggleChore(choreId: chore.id, periodKey: chore.periodKey, completed: true)
            isChecked = true
            withAnimation { isHidden = true }
        } catch {
            // Leave it unchecked rather than showing a completion that didn't happen.
            isChecked = false
        }
    }
}

/// A snack with a circle for each child, for households that track snacks per child.
struct SnackChildTile: View {
    @EnvironmentObject private var appState: AppState
    let snack: String
    let children: [Profile]
    let records: [SnackEatenRecord]
    let isDone: Bool
    let localDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snack)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(isDone ? HubTheme.muted : .primary)
                .strikethrough(isDone, color: HubTheme.muted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            SnackChildChips(snack: snack, children: children, records: records) { child, eaten in
                do {
                    try await appState.toggleSnack(localDate: localDate, label: snack, profileId: child.id, completed: eaten)
                } catch {
                    appState.report(error)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DashboardSnackCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let label: String
    let localDate: String
    let isEaten: Bool
    @State private var isChecked: Bool
    @State private var isWorking = false

    init(label: String, localDate: String, isEaten: Bool) {
        self.label = label
        self.localDate = localDate
        self.isEaten = isEaten
        _isChecked = State(initialValue: isEaten)
    }

    var body: some View {
        Button {
            Task {
                guard !isWorking else { return }
                isWorking = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let previous = isChecked
                isChecked.toggle()
                do {
                    try await appState.toggleSnack(localDate: localDate, label: label, completed: !previous)
                } catch {
                    isChecked = previous
                }
                isWorking = false
            }
        } label: {
            DashboardRow(title: label, isDone: isChecked) {
                DashboardCheckMarker(isChecked: isChecked)
            } trailing: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityValue(isChecked ? "Eaten" : "Not eaten")
        .accessibilityAddTraits(.isToggle)
        .onChange(of: isEaten) { _, eaten in
            isChecked = eaten
        }
    }
}

struct DashboardGroceryItemRow: View {
    @EnvironmentObject private var appState: AppState
    let item: GroceryItem
    /// False under an aisle heading, where the aisle is already said and only a quantity belongs here.
    var showsCategory = true
    @State private var isChecked: Bool
    @State private var isHidden = false
    @State private var isWorking = false
    @Environment(\.dashboardRowIsCompact) private var isCompact

    init(item: GroceryItem, showsCategory: Bool = true) {
        self.item = item
        self.showsCategory = showsCategory
        _isChecked = State(initialValue: item.checked)
    }

    var body: some View {
        if !isHidden {
            Button {
                Task { await check() }
            } label: {
                DashboardRow(
                    title: item.title,
                    // In the tighter rows the full name matters more than its category, which would
                    // otherwise squeeze the name onto one truncated line.
                    subtitle: isCompact ? nil : DashboardRowHelpers.grocerySubtitle(
                        quantity: item.quantity,
                        category: item.category,
                        isServerBacked: item.householdId != nil && showsCategory
                    ),
                    isDone: isChecked
                ) {
                    DashboardCheckMarker(isChecked: isChecked)
                } trailing: {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking || !appState.canManageHousehold)
            .accessibilityValue(isChecked ? "Checked off" : "Not checked off")
            .accessibilityAddTraits(.isToggle)
        }
    }

    private func check() async {
        guard !isWorking else { return }
        isWorking = true
        isChecked = true
        do {
            try await appState.setGroceryItemChecked(id: item.id, checked: true)
        } catch {
            // Previously this hid the row even when the write failed.
            isChecked = false
            isWorking = false
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            isHidden = true
        }
        isWorking = false
    }
}

/// Height of a per-child snack tile, which carries a row of child circles and so is not the
/// shared row.
enum DashboardCheckTile {
    /// A per-child snack tile: padding, up to two title lines, then the child circles (which wrap
    /// onto more lines for a large family).
    static func snackChildHeight(title: String, childCount: Int, columnWidth: CGFloat) -> CGFloat {
        let titleLineCount = DashboardRowHelpers.estimatedLineCount(
            characterCount: title.count,
            availableWidth: columnWidth - 20,
            averageCharacterWidth: DashboardMetrics.scaled(9),
            maxLines: 2
        )
        let chipRows = DashboardRowHelpers.chipRowCount(
            count: childCount,
            availableWidth: columnWidth - 20,
            chipSize: SnackChildChips.chipSize,
            spacing: SnackChildChips.spacing
        )
        let chips = CGFloat(chipRows) * SnackChildChips.chipSize + CGFloat(max(0, chipRows - 1)) * SnackChildChips.spacing
        return 20 + CGFloat(titleLineCount) * DashboardMetrics.scaled(20) + 6 + chips
    }
}

extension View {
    /// Runs `action` every `seconds` while the view is on screen. Unlike `onReceive(Timer.publish(...))`,
    /// nothing is created each time the view redraws, and the loop ends by itself when the view goes away.
    func onTick(every seconds: TimeInterval, perform action: @escaping @MainActor () -> Void) -> some View {
        task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                action()
            }
        }
    }
}
