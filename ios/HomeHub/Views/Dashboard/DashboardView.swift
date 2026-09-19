import Combine
import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var compactNavigationPath = NavigationPath()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack(path: $compactNavigationPath) {
                    GeometryReader { proxy in
                        let cards = dashboardCards
                        let layout = DashboardCardLayout(
                            cards: cards,
                            cardSizes: appState.hubModules.dashboardCardSizes,
                            availableSize: proxy.size,
                            isCompact: true,
                            usesFlexibleMacLayout: false
                        )
                        dashboardContent(cards: cards, layout: layout, isCompact: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
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
                    let cards = dashboardCards
                    let layout = DashboardCardLayout(
                        cards: cards,
                        cardSizes: appState.hubModules.dashboardCardSizes,
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
            await appState.refreshDashboard()
        }
        .task {
            if appState.dashboard == nil {
                await appState.refreshDashboard()
            } else {
                await appState.refreshNativeTodaySchedule()
            }
        }
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
                let scheduleEvents = appState.nativeCalendar.hasFullAccess
                    ? appState.nativeTodayScheduleEvents
                    : []
                let calendarConnected = appState.nativeCalendar.hasFullAccess

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

    private var dashboardCards: [DashboardCardId] {
        appState.hubModules.dashboardOrder.filter { appState.hubModules.isDashboardCardEnabled($0) }
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
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
            ) {
                WeatherDashboardPanel()
            }
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
                let pending = dashboard.chores.filter { !$0.completed }
                DashboardChecklistPanel(
                    isEmpty: pending.isEmpty,
                    emptyTitle: dashboard.chores.isEmpty
                        ? "Add the first family chore."
                        : "All chores done!",
                    emptyAction: { openDestination(.chores) }
                ) {
                    ForEach(pending.prefix(5)) { chore in
                        ChoreCheckRow(chore: chore)
                    }
                }
            }
        case .meals:
            DashboardPanel(
                systemImage: card.systemImage,
                title: card.label,
                destination: card.destination,
                height: rowHeight,
                fillsHeight: fillsHeight
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
                .font(.system(size: horizontalSizeClass == .compact ? 26 : 32, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
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

private struct WeatherDashboardPanel: View {
    @EnvironmentObject private var appState: AppState

    private var service: NativeWeatherService {
        appState.nativeWeather
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weather = service.snapshot {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(HubTheme.sage)
                        .frame(width: 52, height: 52)
                        .background(HubTheme.tileQuiet)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(weather.temperature)°")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(weather.condition)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Feels like \(weather.feelsLike)°")
                    Text(weatherDetailLine(weather))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)

                Spacer(minLength: 0)

                Text("Updated \(DateHelpers.timeString(weather.updatedAt, timezone: .current))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            } else {
                EmptyStateView(text: emptyText, action: setupAction)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await appState.nativeWeather.activateIfAuthorized()
        }
    }

    private var emptyText: String {
        switch service.accessStatus {
        case .notDetermined:
            return "Allow location to show local weather."
        case .denied, .restricted:
            return "Location access is off for weather."
        case .unavailable:
            return "Weather is unavailable on this device."
        case .authorized:
            if let error = service.errorMessage {
                return error
            }
            return service.isLoading ? "Loading weather..." : "Weather will appear here."
        }
    }

    private var setupAction: (() -> Void)? {
        switch service.accessStatus {
        case .notDetermined, .authorized:
            return {
                Task { await appState.requestNativeWeatherAccessAndRefresh() }
            }
        case .denied, .restricted, .unavailable:
            return nil
        }
    }

    private func weatherDetailLine(_ weather: NativeWeatherSnapshot) -> String {
        var details: [String] = []
        if let high = weather.high {
            details.append("High \(high)°")
        }
        if let low = weather.low {
            details.append("Low \(low)°")
        }
        if let precipitationChance = weather.precipitationChance {
            details.append("Rain \(precipitationChance)%")
        }
        return details.joined(separator: " · ")
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

// MARK: - Routines

private struct RoutinesDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData

    private var groups: [RoutineProgressGroup] {
        RoutineProgressGroup.groups(
            profiles: dashboard.profiles,
            steps: dashboard.routineSteps
        )
    }

    var body: some View {
        if dashboard.routineSteps.isEmpty {
            EmptyStateView(
                text: "Add a morning or bedtime routine.",
                action: { openHubDestination(.routines) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groups.allSatisfy({ $0.isComplete }) {
            EmptyStateView(
                text: "All routines done for today!",
                action: { openHubDestination(.routines) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(groups) { group in
                        RoutineProgressRow(group: group)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
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

private struct RoutineProgressRow: View {
    let group: RoutineProgressGroup

    private var tint: Color {
        HubTheme.profileColor(group.color)
    }

    private var previewSteps: [RoutineStepRow] {
        Array(group.remainingSteps.prefix(3))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            progressAvatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.name)
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)

                    Text("\(group.completedCount)/\(group.totalCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)

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
                    }
                }
            }
        }
        .padding(10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.completedCount) of \(group.totalCount) routine steps complete")
    }

    private var progressAvatar: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: group.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ProfileAvatarView(
                name: group.name,
                avatar: group.avatar,
                color: group.color,
                size: 38
            )
            .padding(5)
        }
        .frame(width: 52, height: 52)
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
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData
    let height: CGFloat
    var fillsHeight = true

    @State private var now = Date.now
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var childProfiles: [Profile] {
        NapHelpers.childProfiles(from: dashboard.profiles)
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
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: fillsHeight ? height : nil, alignment: .topLeading)
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

        HStack(alignment: .center, spacing: 10) {
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
                                do {
                                    try await appState.api.endNap(napId: activeLogId)
                                    await appState.refreshDashboard()
                                } catch {
                                    appState.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .mini))
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
    @Environment(\.openHubDestination) private var openHubDestination
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
                    action: {
                        if appState.hubModules.snacks {
                            appState.pendingFoodSection = .snacks
                        }
                        openHubDestination(.meals)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let visibleCount = Self.visibleSnackCount(
                        forHeight: geo.size.height,
                        total: sortedSnacks.count
                    )
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(sortedSnacks.prefix(visibleCount), id: \.self) { snack in
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !dashboard.snackOptions.isEmpty {
                Text("\(dashboard.snackEaten.count) of \(dashboard.snackOptions.count) eaten today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Fits as many 2-column snack rows as the card height allows.
    private static func visibleSnackCount(forHeight height: CGFloat, total: Int) -> Int {
        let rowHeight: CGFloat = 40
        let spacing: CGFloat = 8
        let rows = max(1, Int(floor((height + spacing) / (rowHeight + spacing))))
        return min(total, rows * 2)
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
        let items = Array(visibleItems.prefix(6))
        VStack(spacing: 8) {
            if items.isEmpty {
                EmptyStateView(
                    text: "Start a shared grocery list.",
                    action: { openHubDestination(.groceries) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(items) { item in
                            DashboardGroceryItemRow(item: item)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                Text("\(visibleItems.count) to buy")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct NotesDashboardPanel: View {
    @EnvironmentObject private var appState: AppState
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
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(dashboard.notes.prefix(5)) { note in
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
                .scrollIndicators(.hidden)
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
            appState.errorMessage = error.localizedDescription
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
            appState.errorMessage = error.localizedDescription
        }
    }
}

private struct NoteRow: View {
    let note: HouseholdNote
    let canDelete: Bool
    let isDeleting: Bool
    let onDelete: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "note.text")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.sage)
                .frame(width: 24, height: 24)
                .background(HubTheme.sage.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: note.body.isEmpty ? 1 : 0)

            if canDelete {
                Button {
                    Task { await onDelete() }
                } label: {
                    Image(systemName: isDeleting ? "hourglass" : "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(HubTheme.muted)
                .disabled(isDeleting)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BirthdaysDashboardPanel: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let dashboard: DashboardData

    private var items: [BirthdayItem] {
        Array(dashboard.upcomingBirthdays.prefix(4))
    }

    var body: some View {
        if items.isEmpty {
            EmptyStateView(
                text: "Add a birthday to keep dates in view.",
                action: { openHubDestination(.birthdays) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(HubTheme.profileColor(item.color))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                            Text(BirthdayHelpers.countdownLabel(daysUntil: item.daysUntil))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Spacer(minLength: 0)
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
    @State private var isCelebrating = false
    @State private var isWorking = false
    @State private var isHidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(step: RoutineStepRow, localDate: String) {
        self.step = step
        self.localDate = localDate
        _isChecked = State(initialValue: step.completed)
    }

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    guard !isWorking else { return }
                    isWorking = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.56)) {
                        isCelebrating = true
                        isChecked = true
                    }
                    do {
                        try await appState.api.toggleRoutineStep(
                            ToggleRoutineStepRequest(stepId: step.id, localDate: localDate)
                        )
                    } catch {
                        withAnimation {
                            isCelebrating = false
                            isChecked = false
                        }
                        isWorking = false
                        return
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let delay = reduceMotion ? 160_000_000 : 900_000_000
                    try? await Task.sleep(nanoseconds: UInt64(delay))
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHidden = true
                    }
                    await appState.refreshDashboard()
                }
            } label: {
                let display = RoutineGlyphs.display(for: step.label)
                let tint = HubTheme.profileColor(profileColor)

                ZStack {
                    HStack(spacing: 10) {
                        Text(display.glyph)
                            .font(.system(size: 28))
                            .frame(width: 46, height: 46)
                            .background(tint.opacity(isCelebrating ? 0.26 : 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .scaleEffect(isCelebrating && !reduceMotion ? 1.12 : 1)
                            .rotationEffect(.degrees(isCelebrating && !reduceMotion ? -6 : 0))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(display.label)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(isCelebrating ? "Great job!" : (step.profileId == nil ? step.routineName : profileName))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isCelebrating ? tint : HubTheme.muted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isCelebrating || isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(isCelebrating || isChecked ? tint : HubTheme.muted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(tint.opacity(isCelebrating ? 0.20 : 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(isCelebrating ? 0.62 : 0.18), lineWidth: 1.5)
                    )
                    .overlay {
                        if isCelebrating && !reduceMotion {
                            RoutineCelebrationBurst(tint: tint, compact: true)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
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
                isChecked.toggle()
                try? await appState.api.toggleSnack(
                    ToggleSnackRequest(localDate: localDate, snackLabel: label)
                )
                await appState.refreshDashboard()
                isWorking = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isChecked ? HubTheme.sage : HubTheme.muted)
                Text(label)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(isChecked ? HubTheme.muted : .primary)
                    .strikethrough(isChecked, color: HubTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(isChecked ? HubTheme.tileQuiet : HubTheme.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    init(item: GroceryItem) {
        self.item = item
        _isChecked = State(initialValue: item.checked)
    }

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    guard !isWorking else { return }
                    isWorking = true
                    isChecked = true
                    if appState.nativeReminders.hasFullAccess && appState.nativeReminders.selectedListId != nil {
                        try? appState.nativeReminders.setCompleted(itemId: item.id, completed: true)
                        await appState.refreshNativeGroceryItems()
                    } else {
                        _ = try? await appState.api.toggleGroceryItem(id: item.id, checked: true)
                        await appState.refreshDashboard()
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHidden = true
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isChecked ? HubTheme.sage : HubTheme.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(item.quantity ?? item.category)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(HubTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isWorking || !appState.canManageHousehold)
        }
    }
}
