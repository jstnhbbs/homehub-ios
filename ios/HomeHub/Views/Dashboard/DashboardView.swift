import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var compactNavigationPath = NavigationPath()
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
                    .navigationTitle("Today")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HubDestination.self) { destination in
                        compactDestinationPage(destination)
                    }
                }
                .environment(\.openHubDestination) { destination in
                    openDestination(destination)
                }
            } else {
                GeometryReader { proxy in
                    let isCompact = proxy.size.width < 620
                    let cards = dashboardCards(for: .tablet)
                    let layout = DashboardCardLayout(
                        cards: cards,
                        cardSizes: appState.hubModules.dashboardCardSizes(for: .tablet),
                        availableSize: proxy.size,
                        isCompact: isCompact,
                        usesFlexibleMacLayout: isRunningAsIPadAppOnMac
                    )
                    let contentMaxWidth: CGFloat? = isRunningAsIPadAppOnMac ? nil : 1_500
                    dashboardContent(cards: cards, layout: layout, isCompact: isCompact)
                        .frame(maxWidth: contentMaxWidth, maxHeight: .infinity, alignment: .topLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

                    VerifyEmailCard()

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

                        // Hand-packed rows rather than a LazyVGrid, because a grid with a
                        // fixed column count can't let a card span both columns.
                        let cardSizes = appState.hubModules.dashboardCardSizes(for: .phone)
                        let tileRows = compactTileRows(
                            compactGridCards(cards, dashboard: dashboard),
                            sizes: cardSizes
                        )
                        ForEach(Array(tileRows.enumerated()), id: \.offset) { _, row in
                            // fixedSize makes the row as tall as its tallest tile; the tiles then
                            // stretch to match, so a pair never ends up ragged.
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(row) { card in
                                    let span = card.compactSpan(size: cardSizes[card, default: .standard])
                                    CompactDashboardTile(
                                        card: card,
                                        dashboard: dashboard,
                                        span: span,
                                        onNavigate: openDestination
                                    )
                                }
                                // Stops a lone half-width tile stretching across the row.
                                if row.count == 1,
                                   row[0].compactSpan(size: cardSizes[row[0], default: .standard]) == .half {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
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

            VerifyEmailCard()

            if let dashboard = appState.dashboard {
                let scheduleEvents = appState.nativeCalendar.hasFullAccess
                    ? appState.nativeTodayScheduleEvents
                    : []
                let calendarConnected = appState.nativeCalendar.hasFullAccess
                let todaysBirthdays = birthdaysToday(dashboard)

                if !todaysBirthdays.items.isEmpty {
                    BirthdayTodayBanners(items: todaysBirthdays.items, localDate: todaysBirthdays.localDate)
                }

                if cards.isEmpty {
                    ContentUnavailableView(
                        "No Today Cards",
                        systemImage: "rectangle.3.group",
                        description: Text("Turn cards back on in Settings.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(layout.rows(for: cards).enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(row) { item in
                                        dashboardCard(
                                            item.card,
                                            dashboard: dashboard,
                                            rowHeight: layout.rowHeight,
                                            fillsHeight: !isCompact,
                                            isCompact: isCompact,
                                            scheduleEvents: scheduleEvents,
                                            calendarConnected: calendarConnected
                                        )
                                        .frame(width: layout.width(for: item))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
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

    private func dashboardCards(for target: DashboardLayoutTarget) -> [DashboardCardId] {
        appState.hubModules.dashboardOrder(for: target).filter { card in
            // Weather is ambient with no destination and no actions, so it renders in
            // the header rather than consuming a tile. Its toggle still gates it there.
            card != .weather && appState.hubModules.isDashboardCardEnabled(card)
        }
    }

    @ViewBuilder
    private func dashboardCard(
        _ card: DashboardCardId,
        dashboard: DashboardData,
        rowHeight: CGFloat,
        fillsHeight: Bool,
        isCompact: Bool,
        scheduleEvents: [ScheduleEvent],
        calendarConnected: Bool
    ) -> some View {
        switch card {
        case .weather:
            // Weather renders in HubHeaderView, never as a card. `dashboardCards`
            // filters it out upstream; this case only exists for exhaustiveness.
            EmptyView()
        case .schedule:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                TodaySchedulePanel(
                    events: scheduleEvents,
                    timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current,
                    connected: calendarConnected
                ) {
                    openDestination(.settings)
                }
            }
        case .routines:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                RoutinesDashboardPanel(dashboard: dashboard)
            }
        case .chores:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                ChoresDashboardPanel(dashboard: dashboard)
            }
        case .meals:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                // Only whole meal tiles are shown; a slot that does not fit becomes "+N more".
                WholeRowsGrid(
                    items: [MealSlot.breakfast, .lunch, .dinner].map { slot in
                        MealTile(slot: slot, meal: dashboard.meals.first { $0.slot == slot })
                    },
                    minimumColumnWidth: 125,
                    maxColumns: 3,
                    itemHeight: { tile, columnWidth in MealSlotRow.height(for: tile.meal, columnWidth: columnWidth) },
                    onMore: { openDestination(.meals) }
                ) { tile, _ in
                    MealSlotRow(slot: tile.slot, meal: tile.meal)
                }
            }
        case .snacks:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight,
                onNavigate: {
                    if appState.hubModules.snacks {
                        appState.pendingFoodSection = .snacks
                    }
                    openDestination(.meals)
                }
            ) {
                SnacksDashboardPanel(dashboard: dashboard)
            }
        case .sleep:
            NapsDashboardPanel(dashboard: dashboard, height: rowHeight, fillsHeight: fillsHeight)
        case .groceries:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                GroceriesDashboardPanel(dashboard: dashboard)
            }
        case .notes:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                NotesDashboardPanel(dashboard: dashboard)
            }
        case .birthdays:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                BirthdaysDashboardPanel(dashboard: dashboard)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if horizontalSizeClass == .compact {
                HouseholdMarkView(
                    name: appState.household?.name ?? "Beacon",
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

private struct CompactNextUpItem {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let destination: HubDestination
}

/// The next thing that needs doing, drawn from routines and chores. Calendar events are left
/// to the Schedule tile below, so the two never say the same thing. When nothing needs
/// attention the card doesn't appear at all rather than spend space saying so.
private struct CompactNextUpPanel: View {
    let dashboard: DashboardData
    let enabledCards: [DashboardCardId]
    let onNavigate: (HubDestination) -> Void

    /// Checks each enabled module in the order the household arranged Today's cards, so
    /// reordering cards in Settings changes what surfaces here, not just the grid below.
    private var item: CompactNextUpItem? {
        for card in enabledCards {
            switch card {
            case .routines:
                if let step = dashboard.routineSteps.first(where: { !$0.completed }) {
                    return CompactNextUpItem(
                        eyebrow: "NEXT ROUTINE",
                        title: RoutineGlyphs.display(for: step.label).label,
                        detail: step.profileId.flatMap(profileName) ?? step.routineName,
                        systemImage: "checklist",
                        destination: .routines
                    )
                }
            case .chores:
                if let chore = dashboard.chores.first(where: { !$0.completed }) {
                    return CompactNextUpItem(
                        eyebrow: "NEXT CHORE",
                        title: chore.title,
                        detail: chore.profileId.flatMap(profileName) ?? "Anyone",
                        systemImage: "checkmark.square.fill",
                        destination: .chores
                    )
                }
            default:
                continue
            }
        }
        return nil
    }

    var body: some View {
        if let item {
            Button {
                onNavigate(item.destination)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HubTheme.sage)
                        .frame(width: 38, height: 38)
                        .background(HubTheme.sage.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.eyebrow)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.sage)
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
        }
    }

    private func profileName(_ id: String) -> String? {
        dashboard.profiles.first { $0.id == id }?.name
    }
}

// MARK: - Compact tile building blocks

/// Scalars read well two-up; content-heavy cards get the whole row. This is the
/// mixed-width rhythm a fixed-column grid can't express.
private enum CompactTileSpan {
    case half
    case full
}

private extension DashboardCardId {
    /// Content that cannot work in a half-width tile whatever the preference says.
    /// Notes hosts a live text field, and a ~150pt input is unusable.
    var requiresFullCompactWidth: Bool { self == .notes }

    /// iPhone has two columns, so the existing card size maps straight across:
    /// standard spans one column, expanded spans both.
    func compactSpan(size: DashboardCardSize) -> CompactTileSpan {
        if requiresFullCompactWidth { return .full }
        return size == .expanded ? .full : .half
    }

    /// Shortened so a half-width tile header doesn't truncate.
    var compactTitle: String {
        switch self {
        case .schedule: "Schedule"
        case .routines: "Routines"
        case .meals: "Meals"
        default: label
        }
    }

}

/// Packs cards into rows, preserving the user's chosen order while pairing
/// half-width tiles and giving full-width tiles a row to themselves.
private func compactTileRows(
    _ cards: [DashboardCardId],
    sizes: [DashboardCardId: DashboardCardSize]
) -> [[DashboardCardId]] {
    var rows: [[DashboardCardId]] = []
    var pendingHalf: DashboardCardId?

    for card in cards {
        switch card.compactSpan(size: sizes[card, default: .standard]) {
        case .full:
            if let pending = pendingHalf {
                rows.append([pending])
                pendingHalf = nil
            }
            rows.append([card])
        case .half:
            if let pending = pendingHalf {
                rows.append([pending, card])
                pendingHalf = nil
            } else {
                pendingHalf = card
            }
        }
    }

    if let pending = pendingHalf {
        rows.append([pending])
    }
    return rows
}

/// Big number, qualifier, optional progress bar — the unit of a compact tile.
private struct CompactMetric: View {
    let value: String
    let detail: String
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .lineLimit(1)
            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(HubTheme.sage)
            }
        }
    }
}

private struct CompactDetailChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

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

/// Chrome every compact tile shares: header with drill-in chevron, frame, background.
private struct CompactTileShell<Content: View>: View {
    let card: DashboardCardId
    let span: CompactTileSpan
    let onNavigate: (HubDestination) -> Void
    var beforeNavigate: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content()
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }

    /// Standard tiles keep one fixed size so the grid looks the same whichever modules a household
    /// has on; a household with few cards shouldn't get differently sized tiles. Full-width tiles
    /// hold a variable amount (a schedule may have one event or three), so they fit their content.
    private var minHeight: CGFloat {
        span == .half ? 154 : 88
    }

    @ViewBuilder
    private var header: some View {
        if let destination = card.destination {
            Button {
                beforeNavigate?()
                onNavigate(destination)
            } label: {
                headerLabel(showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            headerLabel(showsChevron: false)
        }
    }

    private func headerLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: card.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.sage)
            Text(card.compactTitle)
                .font(.caption.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Thin dispatcher: each card's data and actions live in its own summary view.
private struct CompactDashboardTile: View {
    @EnvironmentObject private var appState: AppState

    let card: DashboardCardId
    let dashboard: DashboardData
    let span: CompactTileSpan
    let onNavigate: (HubDestination) -> Void

    /// A half-width tile can only show a couple of names before they truncate;
    /// a full-width one has room for the whole group.
    private var groupRowLimit: Int { span == .full ? 8 : 4 }

    var body: some View {
        CompactTileShell(
            card: card,
            span: span,
            onNavigate: onNavigate,
            beforeNavigate: card == .snacks ? { appState.pendingFoodSection = .snacks } : nil
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch card {
        case .weather:
            // Weather renders in the header readout, never as a tile.
            EmptyView()
        case .schedule:
            CompactScheduleSummary(dashboard: dashboard)
        case .routines:
            if dashboard.routineSteps.isEmpty {
                CompactDetailChip(text: "No routines yet")
            } else {
                CompactRoutinesSummary(dashboard: dashboard, visibleLimit: groupRowLimit)
            }
        case .chores:
            if dashboard.chores.isEmpty {
                CompactDetailChip(text: "No chores due today")
            } else {
                CompactChoresSummary(dashboard: dashboard, visibleLimit: groupRowLimit)
            }
        case .meals:
            CompactMealSummary(
                meals: dashboard.meals,
                timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current
            )
        case .snacks:
            CompactSnacksSummary(dashboard: dashboard)
        case .sleep:
            CompactSleepSummary(dashboard: dashboard)
        case .groceries:
            CompactGroceriesSummary(dashboard: dashboard)
        case .notes:
            CompactNotesSummary(dashboard: dashboard)
        case .birthdays:
            CompactBirthdaysSummary(dashboard: dashboard)
        }
    }
}

/// The day's remaining events. The Next Up hero covers routines and chores only, so this tile
/// is the one place calendar events appear on iPhone.
private struct CompactScheduleSummary: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    @State private var now = Date.now

    private var timezone: TimeZone {
        TimeZone(identifier: dashboard.household.timezone) ?? .current
    }

    private var events: [ScheduleEvent] {
        guard appState.nativeCalendar.hasFullAccess else { return [] }
        return Array(
            DashboardHelpers.upcomingScheduleEvents(appState.nativeTodayScheduleEvents, now: now).prefix(3)
        )
    }

    var body: some View {
        Group {
            if !appState.nativeCalendar.hasFullAccess {
                CompactDetailChip(text: "Connect a calendar to see today's schedule.")
            } else if events.isEmpty {
                CompactDetailChip(text: "Nothing left on the calendar today.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(event.allDay
                                 ? "All day"
                                 : DateHelpers.timeString(event.startsAt, timezone: timezone))
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(HubTheme.sage)
                                .monospacedDigit()
                                .lineLimit(1)
                            Text(event.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .onTick(every: 60) { now = Date() }
    }
}

private struct CompactSnacksSummary: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    private var pending: [String] {
        let eaten = Set(dashboard.snackEaten)
        return dashboard.snackOptions.filter { !eaten.contains($0) }
    }
    private var children: [Profile] { NapHelpers.childProfiles(from: dashboard.profiles) }
    private var perChild: Bool { dashboard.snacksPerChild && !children.isEmpty }

    var body: some View {
        CompactMetric(
            value: "\(dashboard.snackEaten.count)/\(dashboard.snackOptions.count)",
            detail: "snacks eaten",
            progress: dashboard.snackOptions.isEmpty
                ? nil
                : Double(dashboard.snackEaten.count) / Double(dashboard.snackOptions.count)
        )
        if let snack = pending.first {
            if perChild {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snack)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    SnackChildChips(snack: snack, children: children, records: dashboard.snackCompletions) { child, eaten in
                        do {
                            try await appState.toggleSnack(localDate: dashboard.localDate, label: snack, profileId: child.id, completed: eaten)
                        } catch {
                            appState.report(error)
                        }
                    }
                }
            } else {
                CompactCheckAction(label: snack) {
                    await compactCompletion(report: appState.report) {
                        // Only snacks not yet eaten are offered here.
                        try await appState.toggleSnack(localDate: dashboard.localDate, label: snack, completed: true)
                    }
                }
                // Keyed to the snack: once it is eaten the next one takes this spot, and without a key
                // it would inherit this one's "done" look and refuse taps.
                .id(snack)
            }
        }
    }
}

private struct CompactGroceriesSummary: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    private var items: [GroceryItem] {
        let source = appState.groceriesUseNativeReminders
            ? appState.nativeGroceryItems
            : dashboard.groceryItems
        return source.filter { !$0.checked }
    }

    var body: some View {
        CompactMetric(
            value: "\(items.count)",
            detail: items.count == 1 ? "item to buy" : "items to buy"
        )
        if let item = items.first {
            CompactCheckAction(label: item.title, enabled: appState.canManageHousehold) {
                await compactCompletion(report: appState.report) {
                    try await appState.setGroceryItemChecked(id: item.id, checked: true)
                }
            }
            // Keyed to the item for the same reason as the snack above.
            .id(item.id)
        }
    }
}

private struct CompactBirthdaysSummary: View {
    let dashboard: DashboardData

    var body: some View {
        if let birthday = dashboard.upcomingBirthdays.first {
            CompactMetric(
                value: birthday.daysUntil == 0 ? "Today" : "\(birthday.daysUntil)d",
                detail: birthday.name
            )
            CompactDetailChip(text: BirthdayHelpers.countdownLabel(daysUntil: birthday.daysUntil))
        } else {
            CompactMetric(value: "0", detail: "coming up")
        }
    }
}

private struct CompactCheckAction: View {
    let label: String
    var enabled = true
    let action: () async -> Bool

    @State private var isWorking = false
    @State private var isComplete = false

    var body: some View {
        Button {
            Task {
                guard !isWorking else { return }
                isWorking = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let succeeded = await action()
                if succeeded {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isComplete = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                isWorking = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isComplete ? HubTheme.sage : HubTheme.muted)
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isComplete ? HubTheme.muted : .primary)
                    .strikethrough(isComplete)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isWorking {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isWorking || isComplete)
        .opacity(enabled ? 1 : 0.55)
    }
}


/// Features one meal, moving through the day on the household's clock (see MealSlotClock):
/// breakfast, then lunch from 10:30 AM, then dinner from 2:30 PM.
private struct CompactMealSummary: View {
    let meals: [Meal]
    let timezone: TimeZone

    var body: some View {
        // Re-evaluated every minute so the meal changes on time without a refresh.
        TimelineView(.everyMinute) { context in
            let slot = MealSlotClock.slot(at: context.date, timezone: timezone)
            let meal = meals.first { $0.slot == slot }
            VStack(alignment: .leading, spacing: 6) {
                Text(slot.label.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(HubTheme.sage)
                Text(meal?.title ?? "Not planned")
                    .font(.headline.weight(.bold))
                    .lineLimit(3)
                    .foregroundStyle(meal == nil ? HubTheme.muted : .primary)
            }
        }
    }
}

private struct CompactSleepSummary: View {
    let dashboard: DashboardData

    private var todaysLogs: [NapLog] {
        dashboard.naps.filter { $0.localDate == dashboard.localDate }
    }

    private var activeLogs: [NapLog] {
        dashboard.naps.filter { $0.endedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activeLogs.isEmpty ? "\(todaysLogs.count)" : "\(activeLogs.count) active")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(activeLogs.isEmpty
                ? (todaysLogs.count == 1 ? "sleep log today" : "sleep logs today")
                : "sleep session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .lineLimit(1)
            // Everyone who is asleep, not just the first, so a big family sees who needs waking.
            ForEach(activeLogs.prefix(3), id: \.id) { active in
                if let profile = dashboard.profiles.first(where: { $0.id == active.profileId }) {
                    Text("\(profile.name) · \(active.kind == "night" ? "In bed" : "Napping")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.sage)
                        .lineLimit(1)
                }
            }
            if activeLogs.count > 3 {
                Text("+\(activeLogs.count - 3) more")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }
}

/// Per-child routine progress for the Today grid: who still has steps left, and their streak.
/// Checking a step off happens on the full Routines screen (one tap away via the tile header);
/// this only needs to answer "which kid needs a nudge" at a glance.
private struct CompactRoutinesSummary: View {
    let dashboard: DashboardData
    let visibleLimit: Int

    private var groups: [RoutineProgressGroup] {
        RoutineProgressGroup.groups(profiles: dashboard.profiles, steps: dashboard.routineSteps)
    }

    private func streak(for group: RoutineProgressGroup) -> Int? {
        let profileId: String? = group.id == "household" ? nil : group.id
        let days = dashboard.routineStreaks.first { $0.profileId == profileId }?.current
        return (days ?? 0) >= StreakHelpers.minimumToShow ? days : nil
    }

    var body: some View {
        CompactGroupRowList(visibleLimit: visibleLimit, rows: groups.map { group in
            CompactGroupRow(
                id: group.id,
                name: group.name,
                color: group.color,
                completed: group.completedCount,
                total: group.totalCount,
                streakDays: streak(for: group)
            )
        })
    }
}

/// Chores grouped the same way as routines, since a parent asks the same question of both:
/// which kid still has something left today.
private struct ChoreProgressGroup: Identifiable {
    let id: String
    let name: String
    let color: String
    let chores: [ChoreRow]

    var completedCount: Int { chores.filter(\.completed).count }
    var totalCount: Int { chores.count }

    static func groups(profiles: [Profile], chores: [ChoreRow]) -> [ChoreProgressGroup] {
        let childProfiles = profiles
            .filter { $0.profileType == .child }
            .sorted { $0.sortOrder < $1.sortOrder }

        var groups = childProfiles.compactMap { profile -> ChoreProgressGroup? in
            let profileChores = chores.filter { $0.profileId == profile.id }
            guard !profileChores.isEmpty else { return nil }
            return ChoreProgressGroup(id: profile.id, name: profile.name, color: profile.color, chores: profileChores)
        }

        let householdChores = chores.filter { $0.profileId == nil }
        if !householdChores.isEmpty {
            groups.append(
                ChoreProgressGroup(id: "household", name: "Family", color: "#4f7c6d", chores: householdChores)
            )
        }

        return groups
    }
}

private struct CompactChoresSummary: View {
    let dashboard: DashboardData
    let visibleLimit: Int

    private var groups: [ChoreProgressGroup] {
        ChoreProgressGroup.groups(profiles: dashboard.profiles, chores: dashboard.chores)
    }

    var body: some View {
        CompactGroupRowList(visibleLimit: visibleLimit, rows: groups.map { group in
            CompactGroupRow(
                id: group.id,
                name: group.name,
                color: group.color,
                completed: group.completedCount,
                total: group.totalCount,
                streakDays: nil
            )
        })
    }
}

private struct CompactGroupRow: Identifiable {
    let id: String
    let name: String
    let color: String
    let completed: Int
    let total: Int
    let streakDays: Int?

    var isComplete: Bool { total > 0 && completed == total }
}

/// Shared by the routines and chores tiles: one line per child, capped so a large family
/// doesn't push the tile past what fits comfortably in a 2-column grid.
private struct CompactGroupRowList: View {
    /// Half-width tiles truncate names past a couple of rows, so the caller decides.
    /// Declared first so call sites can pass the trailing `rows` map last.
    let visibleLimit: Int
    let rows: [CompactGroupRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(rows.prefix(visibleLimit)) { row in
                HStack(spacing: 6) {
                    Circle()
                        .fill(HubTheme.profileColor(row.color))
                        .frame(width: 7, height: 7)
                    Text(row.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if row.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.sage)
                    } else {
                        Text("\(row.completed)/\(row.total)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .monospacedDigit()
                    }
                    if let days = row.streakDays {
                        StreakChip(days: days)
                    }
                }
            }
            if rows.count > visibleLimit {
                Text("+\(rows.count - visibleLimit) more")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }
}

/// The notes tile keeps the quick-add field from the full-size panel: it's how a guest
/// caretaker leaves a note without needing edit access anywhere else in the app.
private struct CompactNotesSummary: View {
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    @State private var draft = ""
    @State private var isSaving = false

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TextField("Add a note", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .submitLabel(.done)
                    .onSubmit { Task { await addNote() } }

                Button {
                    Task { await addNote() }
                } label: {
                    Image(systemName: isSaving ? "hourglass" : "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(HubTheme.sage)
                .clipShape(Circle())
                .disabled(isSaving || trimmedDraft.isEmpty)
            }

            if let note = dashboard.notes.first(where: \.pinned) ?? dashboard.notes.first {
                Text(note.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(dashboard.notes.count == 1 ? "1 shared note" : "\(dashboard.notes.count) shared notes")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
        }
    }

    private func addNote() async {
        let title = trimmedDraft
        guard !title.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await appState.api.addHouseholdNote(HouseholdNoteInput(title: title))
            draft = ""
            await appState.refreshDashboard()
        } catch {
            appState.report(error)
        }
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
    struct RowItem: Identifiable {
        let card: DashboardCardId
        let span: Int

        var id: DashboardCardId { card }
    }

    let cards: [DashboardCardId]
    let cardSizes: [DashboardCardId: DashboardCardSize]
    let availableSize: CGSize
    let isCompact: Bool
    let usesFlexibleMacLayout: Bool

    private var cardCount: Int { cards.count }
    private var spacing: CGFloat { 16 }
    private var contentWidth: CGFloat {
        guard !isCompact else { return max(0, availableSize.width - 32) }
        return usesFlexibleMacLayout ? availableSize.width : min(availableSize.width, 1_500)
    }

    var columnCount: Int {
        guard !isCompact else { return 1 }
        guard cardCount > 0 else { return 1 }

        let widthCap: Int
        if usesFlexibleMacLayout {
            let minimumColumnWidth: CGFloat = 250
            let columnsByWidth = Int(floor((contentWidth + spacing) / (minimumColumnWidth + spacing)))
            widthCap = min(6, max(2, columnsByWidth))
        } else if availableSize.width >= 1_060 {
            widthCap = 4
        } else if availableSize.width >= 720 {
            widthCap = 3
        } else {
            widthCap = 2
        }

        let preferred: Int
        if usesFlexibleMacLayout {
            preferred = flexiblePreferredColumnCount(widthCap: widthCap)
        } else {
            switch cardCount {
            case 1:
                preferred = 1
            case 2:
                preferred = 2
            case 3:
                preferred = 3
            case 4:
                preferred = 2
            case 5...6:
                preferred = 3
            default:
                preferred = 4
            }
        }

        return max(1, min(preferred, widthCap))
    }

    var rowHeight: CGFloat {
        guard !isCompact else { return 300 }

        let rows = max(1, rowCount)
        let rowSpacing = CGFloat(rows - 1) * spacing
        let availableHeight = max(360, availableSize.height - 72 - rowSpacing)
        return max(170, floor(availableHeight / CGFloat(rows)))
    }

    private var rowCount: Int {
        rows(for: cards).count
    }

    func width(for item: RowItem) -> CGFloat? {
        guard !isCompact else { return nil }
        let totalSpacing = CGFloat(columnCount - 1) * spacing
        let columnWidth = max(0, (contentWidth - totalSpacing) / CGFloat(columnCount))
        return columnWidth * CGFloat(item.span) + spacing * CGFloat(item.span - 1)
    }

    func rows(for cards: [DashboardCardId]) -> [[RowItem]] {
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var usedColumns = 0

        for card in cards {
            let span = span(for: card)
            if !currentRow.isEmpty && usedColumns + span > columnCount {
                rows.append(currentRow)
                currentRow = []
                usedColumns = 0
            }

            currentRow.append(RowItem(card: card, span: span))
            usedColumns += span
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private func span(for card: DashboardCardId) -> Int {
        guard !isCompact else { return 1 }
        let size = cardSizes[card, default: .standard]
        return size == .expanded ? min(2, columnCount) : 1
    }

    private func flexiblePreferredColumnCount(widthCap: Int) -> Int {
        guard cardCount > 0 else { return 1 }
        guard cardCount > 3 else { return cardCount }

        var bestColumns = min(cardCount, widthCap)
        var bestScore = Int.max

        for columns in 2...min(cardCount, widthCap) {
            let rows = Int(ceil(Double(cardCount) / Double(columns)))
            let lastRowCount = cardCount - (rows - 1) * columns
            let raggedness = columns - lastRowCount
            let rowPenalty = rows * 2
            let score = raggedness * 3 + rowPenalty

            if score < bestScore {
                bestScore = score
                bestColumns = columns
            }
        }

        return bestColumns
    }
}

private struct DashboardPanel<Content: View>: View {
    @Environment(\.openHubDestination) private var openHubDestination

    let systemImage: String
    let title: String
    let destination: HubDestination?
    let height: CGFloat
    var fillsHeight = true
    var background: Color = HubTheme.tile
    var onNavigate: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitleView(systemImage: systemImage, title: title, action: titleAction)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: fillsHeight ? height : nil, alignment: .topLeading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }

    private var titleAction: (() -> Void)? {
        if let onNavigate {
            return onNavigate
        }

        if let destination {
            return { openHubDestination(destination) }
        }

        return nil
    }
}

/// Today's due, unfinished chores. Shows as many as the card's measured height allows — a
/// household with more room (a wider window, or fewer other cards) sees more without needing to
/// scroll, matching every other list-style dashboard card.
private struct ChoresDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData

    private var pending: [ChoreRow] {
        dashboard.chores.filter { !$0.completed }
    }

    /// Who a chore is for, as the row would say it.
    private func assigneeName(_ chore: ChoreRow) -> String {
        dashboard.profiles.first { $0.id == chore.profileId }?.name ?? "Anyone"
    }

    var body: some View {
        if pending.isEmpty {
            EmptyStateView(
                text: dashboard.chores.isEmpty ? "Add the first family chore." : "All chores done!",
                action: { openHubDestination(.chores) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // The "who" line is only worth showing when chores are for different people.
            let showsAssignee = DashboardRowHelpers.showsAssignee(pending.map(assigneeName))
            WholeRowsGrid(
                items: pending,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: 3,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.chores) },
                allowsCompactRows: true
            ) { chore, _ in
                ChoreCheckRow(chore: chore, showsAssignee: showsAssignee)
            }
        }
    }
}

// MARK: - Routines

private struct RoutinesDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let dashboard: DashboardData

    @State private var celebration: String?

    private var groups: [RoutineProgressGroup] {
        RoutineProgressGroup.groups(
            profiles: dashboard.profiles,
            steps: dashboard.routineSteps
        )
    }

    private func streak(for group: RoutineProgressGroup) -> RoutineStreak? {
        let profileId: String? = group.id == "household" ? nil : group.id
        return dashboard.routineStreaks.first { $0.profileId == profileId }
    }

    var body: some View {
        content
            .overlay(alignment: .top) {
                if let celebration {
                    StreakBanner(text: celebration)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 4)
                }
            }
            .onAppear { celebrateMilestones() }
            .onChange(of: dashboard.routineStreaks) { _, _ in celebrateMilestones() }
    }

    @ViewBuilder
    private var content: some View {
        if dashboard.routineSteps.isEmpty {
            EmptyStateView(
                text: "Add a morning or bedtime routine.",
                action: { openHubDestination(.routines) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groups.allSatisfy({ $0.isComplete }) {
            VStack(spacing: 10) {
                EmptyStateView(
                    text: "All routines done for today!",
                    action: { openHubDestination(.routines) }
                )
                streakSummary
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Full tiles (avatar, three steps, "+N more") are about 120pt tall, so a short card or a
            // big family can only show one or two. When they would not all fit, switch to a compact
            // row per child (and use extra columns if the card is wide), so everyone's progress
            // stays visible at once. Either way only whole rows show.
            GeometryReader { geo in
                let fullColumns = DashboardRowHelpers.columnCount(
                    availableWidth: geo.size.width,
                    minimumColumnWidth: Self.fullMinimumColumnWidth,
                    spacing: 8,
                    maxColumns: 4
                )
                let fullFits = DashboardRowHelpers.allFit(
                    itemHeights: groups.map { RoutineProgressRow.fullHeight(for: $0) },
                    columns: fullColumns,
                    spacing: 8,
                    availableHeight: geo.size.height
                )
                let compactColumns = DashboardRowHelpers.columnCount(
                    availableWidth: geo.size.width,
                    minimumColumnWidth: Self.compactMinimumColumnWidth,
                    spacing: 8,
                    maxColumns: 3
                )
                // Last resort for a big family in a short card: one progress ring per child,
                // which wraps to fit any number of children in a small space.
                let ringsOnly = !fullFits && !DashboardRowHelpers.allFit(
                    itemHeights: Array(repeating: DashboardRow<EmptyView, EmptyView>.compactHeight, count: groups.count),
                    columns: compactColumns,
                    spacing: 8,
                    availableHeight: geo.size.height
                )
                if fullFits {
                    WholeRowsGrid(
                        items: groups,
                        minimumColumnWidth: Self.fullMinimumColumnWidth,
                        maxColumns: 4,
                        itemHeight: { group, _ in RoutineProgressRow.fullHeight(for: group) },
                        onMore: { openHubDestination(.routines) }
                    ) { group, _ in
                        RoutineProgressRow(group: group, streak: streak(for: group))
                    }
                } else if ringsOnly {
                    ScrollView {
                        TagFlowLayout(spacing: 10) {
                            ForEach(groups) { group in
                                RoutineRingChip(group: group)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    WholeRowsGrid(
                        items: groups,
                        minimumColumnWidth: Self.compactMinimumColumnWidth,
                        maxColumns: 3,
                        itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                        onMore: { openHubDestination(.routines) },
                        allowsCompactRows: true
                    ) { group, _ in
                        RoutineCompactRow(group: group, streak: streak(for: group))
                    }
                }
            }
        }
    }

    private static let fullMinimumColumnWidth: CGFloat = 200
    private static let compactMinimumColumnWidth: CGFloat = 175

    /// Everyone's running streak, shown once the day's routines are finished.
    @ViewBuilder
    private var streakSummary: some View {
        let running = groups.compactMap { group -> (String, Int)? in
            guard let days = streak(for: group)?.current, days >= StreakHelpers.minimumToShow else { return nil }
            return (group.name, days)
        }
        if !running.isEmpty {
            HStack(spacing: 12) {
                ForEach(running, id: \.0) { name, days in
                    HStack(spacing: 4) {
                        Text(name).font(.caption.weight(.bold))
                        StreakChip(days: days)
                    }
                }
            }
        }
    }

    /// Shows a banner the first time a child reaches a milestone on a given day.
    private func celebrateMilestones() {
        for group in groups {
            guard let streak = streak(for: group),
                  streak.completedToday,
                  StreakHelpers.isMilestone(streak.current),
                  !StreakHelpers.hasCelebrated(profileKey: group.id, localDate: dashboard.localDate) else { continue }
            StreakHelpers.markCelebrated(profileKey: group.id, localDate: dashboard.localDate)
            let message = StreakHelpers.celebrationMessage(name: group.name, days: streak.current)
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7)) {
                celebration = message
            }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { if celebration == message { celebration = nil } }
            }
            return
        }
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

private struct StreakBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "flame.fill")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct RoutineProgressGroup: Identifiable {
    let id: String
    let name: String
    let color: String
    let avatar: String?
    let steps: [RoutineStepRow]

    var completedCount: Int {
        steps.filter { $0.completed }.count
    }

    var totalCount: Int {
        steps.count
    }

    var remainingSteps: [RoutineStepRow] {
        steps.filter { !$0.completed }
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    static func groups(profiles: [Profile], steps: [RoutineStepRow]) -> [RoutineProgressGroup] {
        let childProfiles = profiles
            .filter { $0.profileType == .child }
            .sorted { $0.sortOrder < $1.sortOrder }

        var groups = childProfiles.compactMap { profile -> RoutineProgressGroup? in
            let profileSteps = steps.filter { $0.profileId == profile.id }
            guard !profileSteps.isEmpty else { return nil }

            return RoutineProgressGroup(
                id: profile.id,
                name: profile.name,
                color: profile.color,
                avatar: profile.avatar,
                steps: profileSteps
            )
        }

        let householdSteps = steps.filter { $0.profileId == nil }
        if !householdSteps.isEmpty {
            groups.append(
                RoutineProgressGroup(
                    id: "household",
                    name: "Family",
                    color: "#4f7c6d",
                    avatar: nil,
                    steps: householdSteps
                )
            )
        }

        return groups
    }
}

/// Progress as a ring around a child's avatar.
private struct RoutineRing: View {
    let group: RoutineProgressGroup
    let diameter: CGFloat

    var body: some View {
        let tint = HubTheme.profileColor(group.color)
        let ring: CGFloat = diameter < 44 ? 3 : 4
        let inset: CGFloat = diameter < 44 ? 3 : 5
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: ring)
            Circle()
                .trim(from: 0, to: group.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ProfileAvatarView(
                name: group.name,
                avatar: group.avatar,
                color: group.color,
                size: diameter - (inset * 2) - ring
            )
            .padding(inset)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A child's routine progress as the shared row: ring, name, the next step, and the count. Used
/// when the full tiles would not all fit.
private struct RoutineCompactRow: View {
    let group: RoutineProgressGroup
    var streak: RoutineStreak?

    private var nextStep: String? {
        guard let next = group.remainingSteps.first else { return nil }
        let display = RoutineGlyphs.display(for: next.label)
        let more = group.remainingSteps.count - 1
        return more > 0 ? "\(display.glyph) \(display.label) +\(more)" : "\(display.glyph) \(display.label)"
    }

    var body: some View {
        let tint = HubTheme.profileColor(group.color)
        DashboardRow(title: group.name, subtitle: nextStep ?? "All set", tint: tint) {
            RoutineRing(group: group, diameter: 28)
        } trailing: {
            HStack(spacing: 4) {
                if let days = streak?.current, days >= StreakHelpers.minimumToShow {
                    StreakChip(days: days)
                }
                if group.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.sage)
                } else {
                    Text("\(group.completedCount)/\(group.totalCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.completedCount) of \(group.totalCount) routine steps complete")
    }
}

/// A child's routine progress as a ring around their avatar with the count underneath. Small
/// enough that a large family still fits in a short card.
private struct RoutineRingChip: View {
    let group: RoutineProgressGroup

    private var tint: Color { HubTheme.profileColor(group.color) }

    var body: some View {
        VStack(spacing: 2) {
            RoutineRing(group: group, diameter: 40)
            if group.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.sage)
                    .frame(height: 13)
            } else {
                Text("\(group.completedCount)/\(group.totalCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .frame(height: 13)
            }
        }
        .frame(width: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.completedCount) of \(group.totalCount) routine steps complete")
    }
}

private struct RoutineProgressRow: View {
    let group: RoutineProgressGroup
    var streak: RoutineStreak?

    /// Height of the full tile: name line, up to three steps, an optional "+N more" line, padding.
    /// Never shorter than the progress ring.
    static func fullHeight(for group: RoutineProgressGroup) -> CGFloat {
        let remaining = group.remainingSteps.count
        let shownSteps = min(3, remaining)
        let stepsHeight: CGFloat
        if shownSteps == 0 {
            stepsHeight = 16
        } else {
            stepsHeight = CGFloat(shownSteps) * 16 + CGFloat(shownSteps - 1) * 4 + (remaining > 3 ? 20 : 0)
        }
        return max(72, 20 + 6 + stepsHeight + 20)
    }

    private var tint: Color {
        HubTheme.profileColor(group.color)
    }

    private var previewSteps: [RoutineStepRow] {
        Array(group.remainingSteps.prefix(3))
    }

    var body: some View {
        fullBody
    }

    private var fullBody: some View {
        HStack(alignment: .top, spacing: 12) {
            RoutineRing(group: group, diameter: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.name)
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)

                    Text("\(group.completedCount)/\(group.totalCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)

                    if let days = streak?.current, days >= StreakHelpers.minimumToShow {
                        StreakChip(days: days)
                    }

                    Spacer(minLength: 0)
                }

                if previewSteps.isEmpty {
                    Text("All set")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(previewSteps) { step in
                            let display = RoutineGlyphs.display(for: step.label)

                            HStack(spacing: 6) {
                                Text(display.glyph)
                                    .font(.caption)
                                    .frame(width: 18, alignment: .leading)

                                Text(display.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                        // The preview is capped at 3 steps regardless of card size; say so rather
                        // than let the rest go unmentioned. The full list is one tap away.
                        if group.remainingSteps.count > previewSteps.count {
                            Text("+\(group.remainingSteps.count - previewSteps.count) more")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.completedCount) of \(group.totalCount) routine steps complete")
    }
}

// MARK: - Schedule

private struct TodaySchedulePanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let events: [ScheduleEvent]
    let timezone: TimeZone
    let connected: Bool
    let onConnect: () -> Void

    @State private var now = Date.now
    @State private var endTimer: Timer?

    private var allUpcomingEvents: [ScheduleEvent] {
        DashboardHelpers.upcomingScheduleEvents(events, now: now)
    }

    /// Only worth a household seeing which calendar an event came from once more than one is
    /// actually in play; otherwise it is the same name under every row. Based on every event
    /// today, not just the ones currently visible, so the format doesn't flicker as the card
    /// resizes and a different number of rows fit.
    private var showsCalendarName: Bool {
        DashboardRowHelpers.showsCalendarName(allUpcomingEvents.map(\.calendarName))
    }

    var body: some View {
        Group {
            if allUpcomingEvents.isEmpty {
                EmptyStateView(text: emptyMessage, action: connected ? nil : onConnect)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WholeRowsGrid(
                    items: allUpcomingEvents,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidthWithStatus,
                    maxColumns: 2,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.calendar) }
                ) { event, _ in
                    ScheduleEventRow(event: event, timezone: timezone, showsCalendarName: showsCalendarName)
                }
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
        .onTick(every: 60) {
            now = Date()
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

private struct MealTile: Identifiable {
    let slot: MealSlot
    let meal: Meal?
    var id: MealSlot { slot }
}

private struct MealSlotRow: View {
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
            averageCharacterWidth: 9,
            maxLines: 2
        )
        let textLines = firstLineCount + (count - 1)
        return 24 + 13 + 4 + CGFloat(textLines) * 20 + CGFloat(count - 1) * 4
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

private struct NapsDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData
    let height: CGFloat
    var fillsHeight = true

    @State private var now = Date.now

    /// Anyone asleep right now comes first, so with a big family in a short card the children
    /// whose nap or night can be ended are always the ones visible.
    private var childProfiles: [Profile] {
        let children = NapHelpers.childProfiles(from: dashboard.profiles)
        let asleep = children.filter { NapHelpers.activeSleep(for: $0.id, in: dashboard.naps) != nil }
        return asleep + children.filter { child in !asleep.contains { $0.id == child.id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitleView(systemImage: "moon.fill", title: "Sleep") {
                openHubDestination(.sleep)
            }
            if childProfiles.isEmpty {
                EmptyStateView(
                    text: "Add a child profile to log sleep.",
                    action: appState.canManageHousehold ? { openHubDestination(.settings) } : nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Same row as every other card; whole rows only, with a "+N more" line when a child
                // does not fit. The hint on how to log sleep shows only when there is room.
                let timezone = TimeZone(identifier: dashboard.household.timezone) ?? .current
                WholeRowsGrid(
                    items: childProfiles,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidthWithStatus,
                    maxColumns: 3,
                        itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.sleep) },
                    spareHint: "Tap Sleep to log naps, bedtime, or edit times.",
                allowsCompactRows: true
            ) { profile, _ in
                    DashboardSleepRow(
                        profile: profile,
                        logs: dashboard.naps,
                        localDate: dashboard.localDate,
                        timezone: timezone,
                        now: now
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: fillsHeight ? height : nil, alignment: .topLeading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
        .onTick(every: 30) { now = Date() }
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
        DashboardRow(title: profile.name, subtitle: statusText(for: status)) {
            ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color, size: 28)
        } trailing: {
            if let activeLogId = status.activeLogId {
                Button(status.state == .inBed ? "Wake up" : "End") { end(activeLogId) }
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

private struct SnackListItem: Identifiable {
    let label: String
    var id: String { label }
}

private struct SnacksDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData

    private var eaten: Set<String> { Set(dashboard.snackEaten) }
    private var sortedSnacks: [SnackListItem] {
        SnackHelpers.sortedSnackOptions(dashboard.snackOptions, eaten: eaten).map(SnackListItem.init)
    }
    private var children: [Profile] { NapHelpers.childProfiles(from: dashboard.profiles) }
    /// Each child has their own circle on each snack.
    private var perChild: Bool { dashboard.snacksPerChild && !children.isEmpty }

    private var summary: String {
        perChild
            ? "\(dashboard.snackEaten.count) of \(dashboard.snackOptions.count) eaten by everyone"
            : "\(dashboard.snackEaten.count) of \(dashboard.snackOptions.count) eaten today"
    }

    private func openSnacks() {
        if appState.hubModules.snacks { appState.pendingFoodSection = .snacks }
        openHubDestination(.meals)
    }

    var body: some View {
        if dashboard.snackOptions.isEmpty {
            EmptyStateView(text: "Add snack options for the family.", action: openSnacks)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // The summary shares the "+N more" line, or shows underneath when everything fits and
            // there is room, so it never costs a row of its own.
            WholeRowsGrid(
                items: sortedSnacks,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: 3,
                itemHeight: { item, columnWidth in
                    perChild
                        ? DashboardCheckTile.snackChildHeight(title: item.label, childCount: children.count, columnWidth: columnWidth)
                        : DashboardRow<EmptyView, EmptyView>.height
                },
                onMore: openSnacks,
                spareHint: summary,
                moreSuffix: summary,
                centersHint: true,
                allowsCompactRows: !perChild
            ) { item, _ in
                if perChild {
                    SnackChildTile(
                        snack: item.label,
                        children: children,
                        records: dashboard.snackCompletions,
                        isDone: eaten.contains(item.label),
                        localDate: dashboard.localDate
                    )
                } else {
                    SnackCheckRow(
                        label: item.label,
                        localDate: dashboard.localDate,
                        isEaten: eaten.contains(item.label)
                    )
                }
            }
        }
    }
}

private struct GroceriesDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    @EnvironmentObject private var appState: AppState
    let dashboard: DashboardData

    private var visibleItems: [GroceryItem] {
        let source = appState.nativeReminders.hasFullAccess && appState.nativeReminders.selectedListId != nil
            ? appState.nativeGroceryItems
            : dashboard.groceryItems
        return source.filter { !$0.checked }
    }

    var body: some View {
        let items = visibleItems
        if items.isEmpty {
            EmptyStateView(
                text: "Start a shared grocery list.",
                action: { openHubDestination(.groceries) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let summary = "\(items.count) to buy"
            // The count shares the "+N more" line, or shows underneath when everything fits and
            // there is room, so it never costs a row of its own.
            WholeRowsGrid(
                items: items,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: 2,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.groceries) },
                spareHint: summary,
                moreSuffix: summary,
                centersHint: true,
                allowsCompactRows: true
            ) { item, _ in
                DashboardGroceryItemRow(item: item)
            }
        }
    }
}

private struct NotesDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData

    @State private var draft = ""
    @State private var isSaving = false
    @State private var deletingId: String?

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Add a note", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .submitLabel(.done)
                    .onSubmit {
                        Task { await addNote() }
                    }

                Button {
                    Task { await addNote() }
                } label: {
                    Image(systemName: isSaving ? "hourglass" : "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(HubTheme.sage)
                .clipShape(Circle())
                .disabled(isSaving || trimmedDraft.isEmpty)
            }

            if dashboard.notes.isEmpty {
                EmptyStateView(text: "Leave a household note.", action: nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WholeRowsGrid(
                    items: dashboard.notes,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidthWithStatus,
                    maxColumns: 2,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.notes) },
                    allowsCompactRows: true
                ) { note, _ in
                    NoteRow(
                        note: note,
                        canDelete: appState.canManageHousehold,
                        isDeleting: deletingId == note.id
                    ) {
                        await delete(note)
                    }
                }
            }
        }
    }

    private func addNote() async {
        let title = trimmedDraft
        guard !title.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await appState.api.addHouseholdNote(HouseholdNoteInput(title: title))
            draft = ""
            await appState.refreshDashboard()
        } catch {
            appState.report(error)
        }
    }

    private func delete(_ note: HouseholdNote) async {
        guard deletingId == nil else { return }
        deletingId = note.id
        defer { deletingId = nil }
        do {
            try await appState.api.deleteHouseholdNote(id: note.id)
            await appState.refreshDashboard()
        } catch {
            appState.report(error)
        }
    }
}

private struct NoteRow: View {
    let note: HouseholdNote
    let canDelete: Bool
    let isDeleting: Bool
    let onDelete: () async -> Void

    var body: some View {
        DashboardRow(title: note.title, subtitle: note.body.isEmpty ? nil : note.body) {
            Image(systemName: "note.text")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.sage)
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
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(HubTheme.muted)
                .disabled(isDeleting)
            }
        }
    }
}

private struct BirthdaysDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData

    /// Every upcoming entry within the year, soonest first. What does not fit the card shows as
    /// "+N more", which opens the full list.
    private var items: [BirthdayItem] {
        dashboard.upcomingBirthdays
    }

    /// Today's date in the household's time zone, so a dashboard loaded yesterday still shows "today".
    private var today: String {
        DateHelpers.localDateIn(timezone: TimeZone(identifier: dashboard.household.timezone) ?? .current)
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(
                text: "Add a birthday or anniversary to keep dates in view.",
                action: { openHubDestination(.birthdays) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // The countdown is the point of this card, so rows keep their full height.
            WholeRowsGrid(
                items: items,
                minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidth,
                maxColumns: 3,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.birthdays) }
            ) { item, _ in
                row(item, isToday: item.nextDate == today)
            }
        }
    }

    private func row(_ item: BirthdayItem, isToday: Bool) -> some View {
        DashboardRow(
            title: item.name,
            subtitle: isToday ? todayLabel(item) : BirthdayHelpers.countdownLabel(daysUntil: item.daysUntil),
            tint: isToday ? .orange : nil,
            tintStrength: 0.14,
            outline: isToday ? Color.orange.opacity(0.5) : nil
        ) {
            if isToday {
                Image(systemName: "party.popper.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else {
                Circle()
                    .fill(HubTheme.profileColor(item.color))
                    .frame(width: 10, height: 10)
            }
        } trailing: {
            EmptyView()
        }
    }

    private func todayLabel(_ item: BirthdayItem) -> String {
        BirthdayToday.ageLine(item.upcomingAge, kind: item.kind) ?? "Today"
    }
}

// MARK: - Check rows

private struct ChoreCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let chore: ChoreRow
    let showsAssignee: Bool
    @State private var isChecked: Bool
    @State private var isWorking = false
    @State private var isHidden = false

    init(chore: ChoreRow, showsAssignee: Bool = true) {
        self.chore = chore
        self.showsAssignee = showsAssignee
        _isChecked = State(initialValue: chore.completed)
    }

    private var assignee: Profile? {
        appState.dashboard?.profiles.first { $0.id == chore.profileId }
    }

    var body: some View {
        if !isHidden {
            Button {
                Task { await toggle() }
            } label: {
                DashboardRow(
                    title: chore.title,
                    subtitle: showsAssignee ? (assignee?.name ?? "Anyone") : nil,
                    isDone: isChecked
                ) {
                    DashboardCheckMarker(isChecked: isChecked)
                } trailing: {
                    if isWorking { ProgressView().controlSize(.small) }
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
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
private struct SnackChildTile: View {
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

private struct SnackCheckRow: View {
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
        .onChange(of: isEaten) { _, eaten in
            isChecked = eaten
        }
    }
}

private struct DashboardGroceryItemRow: View {
    @EnvironmentObject private var appState: AppState
    let item: GroceryItem
    @State private var isChecked: Bool
    @State private var isHidden = false
    @State private var isWorking = false
    @Environment(\.dashboardRowIsCompact) private var isCompact

    init(item: GroceryItem) {
        self.item = item
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
                        isServerBacked: item.householdId != nil
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
private enum DashboardCheckTile {
    /// A per-child snack tile: padding, up to two title lines, then the child circles (which wrap
    /// onto more lines for a large family).
    static func snackChildHeight(title: String, childCount: Int, columnWidth: CGFloat) -> CGFloat {
        let titleLineCount = DashboardRowHelpers.estimatedLineCount(
            characterCount: title.count,
            availableWidth: columnWidth - 20,
            averageCharacterWidth: 9,
            maxLines: 2
        )
        let chipRows = DashboardRowHelpers.chipRowCount(
            count: childCount,
            availableWidth: columnWidth - 20,
            chipSize: SnackChildChips.chipSize,
            spacing: SnackChildChips.spacing
        )
        let chips = CGFloat(chipRows) * SnackChildChips.chipSize + CGFloat(max(0, chipRows - 1)) * SnackChildChips.spacing
        return 20 + CGFloat(titleLineCount) * 20 + 6 + chips
    }
}

private extension View {
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
