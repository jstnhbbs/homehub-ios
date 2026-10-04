import Combine
import SwiftUI

struct NapsView: View {
    var embeddedInHub = false

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var payload: NapsPayload?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var now = Date.now
    @State private var selectedPatternDate: String?
    @State private var showingAddSheet = false
    @State private var editingNap: NapLog?
    /// Bumped by every write, so a reload that started before one can tell its answer is stale.
    @State private var writeVersion = 0

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if embeddedInHub {
                sleepScrollContent
            } else {
                NavigationStack {
                    sleepScrollContent
                        .navigationTitle("Sleep")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
    }

    /// Wide enough to put the timeline and the week panel side by side.
    private static let sideBySideWidth: CGFloat = 820
    private static let weekPanelWidth: CGFloat = 360
    /// A status card needs about this much room before a second one fits beside it.
    private static let statusCardMinWidth: CGFloat = 300

    private var sleepScrollContent: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= Self.sideBySideWidth
            let contentWidth = proxy.size.width - (embeddedInHub ? 0 : 48)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if isLoading && payload == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if let payload {
                        header
                        statusCards(payload, width: contentWidth)
                        if wide {
                            HStack(alignment: .top, spacing: 16) {
                                timelineCard(payload)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                weekCard(payload)
                                    .frame(width: Self.weekPanelWidth, alignment: .topLeading)
                            }
                        } else {
                            timelineCard(payload)
                            weekCard(payload)
                        }
                    }
                }
                .padding(embeddedInHub ? 0 : 24)
            }
        }
        .background(HubTheme.surface)
        .refreshable { await load() }
        .task { await load() }
        .onReceive(timer) { date in
            now = date
        }
        .onChange(of: payload?.localDate) { _, newValue in
            selectedPatternDate = newValue
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSleepSheet(
                childProfiles: payload?.childProfiles ?? [],
                addNap: { profileId, startedAt, endedAt in
                    await createNap(profileId: profileId, startedAt: startedAt, endedAt: endedAt)
                },
                addNight: { profileId, fellAsleepAt, wokeUpAt in
                    await createNightSleep(profileId: profileId, fellAsleepAt: fellAsleepAt, wokeUpAt: wokeUpAt)
                }
            )
        }
        .sheet(item: $editingNap) { nap in
            SleepEntrySheet(
                nap: nap,
                profile: payload?.childProfiles.first { $0.id == nap.profileId },
                timezone: timezone,
                saveAction: { startedAt, endedAt in
                    await updateNap(id: nap.id, startedAt: startedAt, endedAt: endedAt)
                },
                deleteAction: { await deleteNap(id: nap.id) }
            )
        }
    }

    // MARK: Header and status cards

    private var header: some View {
        HStack(alignment: .bottom) {
            if embeddedInHub && horizontalSizeClass != .compact {
                Text("Sleep")
                    .font(HubTheme.pageTitle)
            }
            Spacer()
            Button {
                showingAddSheet = true
            } label: {
                Label("Add past sleep", systemImage: "plus")
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))
        }
    }

    @ViewBuilder
    private func statusCards(_ payload: NapsPayload, width: CGFloat) -> some View {
        if payload.childProfiles.isEmpty {
            HubCard {
                EmptyStateView(text: "Add a child profile in Settings to start logging sleep.")
            }
        } else {
            // One column per child while they fit, so two children share a row and one gets the width.
            let fit = max(1, Int(width / Self.statusCardMinWidth))
            let count = max(1, min(payload.childProfiles.count, fit))
            let logs = sleepLogs(from: payload)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: count), spacing: 16) {
                ForEach(payload.childProfiles) { profile in
                    SleepStatusCard(
                        profile: profile,
                        logs: logs,
                        localDate: payload.localDate,
                        timezone: timezone,
                        now: now,
                        startNap: { await startNap(profileId: profile.id) },
                        startBedtime: { await startNightSleep(profileId: profile.id) },
                        endSleep: { await endNap(napId: $0.id) }
                    )
                }
            }
        }
    }

    // MARK: Timeline

    private func timelineCard(_ payload: NapsPayload) -> some View {
        let selectedDate = selectedPatternDate ?? payload.localDate
        let selectedIndex = payload.weekDates.firstIndex(of: selectedDate) ?? 0
        let dayLogs = NapHelpers.logsForDate(
            profileId: nil,
            in: payload.weekLogs,
            localDate: selectedDate,
            timezone: timezone,
            now: now
        ).sorted { $0.startedAt < $1.startedAt }

        return HubCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timeline")
                            .font(.title3.weight(.semibold))
                        Text("\(DateHelpers.formatLocalDate(selectedDate, timezone: timezone, pattern: "EEEE, MMMM d"))\(selectedDate == payload.localDate ? " · Today" : "")")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { shiftPatternDate(payload: payload, delta: -1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                        .disabled(selectedIndex <= 0)
                        Button("Today") { selectedPatternDate = payload.localDate }
                            .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                            .disabled(selectedDate == payload.localDate)
                        Button { shiftPatternDate(payload: payload, delta: 1) } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                        .disabled(selectedIndex >= payload.weekDates.count - 1)
                    }
                }

                if payload.childProfiles.isEmpty {
                    EmptyStateView(text: "Add a child profile in Settings to see their day.")
                } else {
                    ForEach(payload.childProfiles) { profile in
                        timelineLane(profile: profile, payload: payload, selectedDate: selectedDate)
                    }
                    timelineAxis
                }

                Divider()

                if dayLogs.isEmpty {
                    Text("No sleep logged on this day.")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(dayLogs.enumerated()), id: \.element.id) { index, nap in
                            if let profile = payload.childProfiles.first(where: { $0.id == nap.profileId }) {
                                if index > 0 { Divider() }
                                entryRow(nap, profile: profile)
                            }
                        }
                    }
                }
            }
        }
    }

    private func timelineLane(profile: Profile, payload: NapsPayload, selectedDate: String) -> some View {
        let profileDayLogs = NapHelpers.logsForDate(
            profileId: profile.id,
            in: payload.weekLogs,
            localDate: selectedDate,
            timezone: timezone,
            now: now
        )
        let bars = NapTimelineHelpers.dayTimelineBars(naps: profileDayLogs, localDate: selectedDate, timezone: timezone, now: now)
        let gaps = NapTimelineHelpers.awakeGaps(naps: profileDayLogs, localDate: selectedDate, timezone: timezone)
        let totalMinutes = profileDayLogs.reduce(0) {
            $0 + NapHelpers.overlapMinutes(startedAt: $1.startedAt, endedAt: $1.endedAt, localDate: selectedDate, timezone: timezone, now: now)
        }
        let napCount = profileDayLogs.filter { $0.kind == "nap" }.count
        let nightCount = profileDayLogs.filter { $0.kind == "night" }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(HubTheme.profileColor(profile.color)).frame(width: 12, height: 12)
                Text(profile.name).font(.subheadline.weight(.bold))
                Text(NapHelpers.daySummary(napCount: napCount, nightCount: nightCount, totalMinutes: totalMinutes))
                    .font(.caption.weight(.bold)).foregroundStyle(HubTheme.muted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HubTheme.tileQuiet)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(HubTheme.line))

                    ForEach(gaps) { gap in
                        let frame = timelineFrame(leftPercent: gap.leftPercent, widthPercent: gap.widthPercent, trackWidth: geometry.size.width)
                        Text(gap.widthPercent > 14 ? gap.label : "")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 6)
                            .frame(width: frame.width)
                            .offset(x: frame.x)
                    }

                    ForEach(bars) { bar in
                        let frame = timelineFrame(leftPercent: bar.leftPercent, widthPercent: bar.widthPercent, trackWidth: geometry.size.width)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HubTheme.profileColor(profile.color))
                            .frame(width: frame.width)
                            // Padding, not offset: an offset moves the drawing but not the layout,
                            // so the duration label below stayed at the left edge of the lane.
                            .overlay {
                                if bar.widthPercent > 10 {
                                    Text(bar.durationLabel)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingNap = profileDayLogs.first { $0.id == bar.napId }
                            }
                            .padding(.leading, frame.x)
                    }

                    if bars.isEmpty {
                        Text("No sleep logged")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(height: 48)
        }
    }

    /// Hour labels under the lanes, placed on the same 5a to 11p scale the bars use.
    private var timelineAxis: some View {
        let labels = NapTimelineHelpers.hourLabels
        return GeometryReader { geometry in
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let fraction = CGFloat(index) / CGFloat(max(labels.count - 1, 1))
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .fixedSize()
                    .position(x: min(max(geometry.size.width * fraction, 10), geometry.size.width - 10), y: 7)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private func entryRow(_ nap: NapLog, profile: Profile) -> some View {
        let end = nap.endedAt.map { DateHelpers.timeString($0, timezone: timezone) } ?? (nap.kind == "night" ? "still asleep" : "in progress")
        let duration = NapHelpers.formatDuration(minutes: NapHelpers.durationMinutes(startedAt: nap.startedAt, endedAt: nap.endedAt, now: now))
        return Button {
            editingNap = nap
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(HubTheme.profileColor(profile.color))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile.name) · \(nap.kind == "night" ? "Night" : "Nap")")
                        .font(.subheadline.weight(.bold))
                    Text("\(DateHelpers.timeString(nap.startedAt, timezone: timezone)) – \(end)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
                Spacer()
                Text(duration)
                    .font(.subheadline.weight(.bold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit or delete this entry")
    }

    // MARK: Week

    private func weekCard(_ payload: NapsPayload) -> some View {
        let selectedDate = selectedPatternDate ?? payload.localDate
        return HubCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.title3.weight(.semibold))
                    if let start = payload.weekDates.first, let end = payload.weekDates.last {
                        Text("\(DateHelpers.formatLocalDate(start, timezone: timezone, pattern: "MMM d")) – \(DateHelpers.formatLocalDate(end, timezone: timezone, pattern: "MMM d"))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                ForEach(Array(payload.childProfiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { Divider() }
                    weekBlock(profile: profile, payload: payload, selectedDate: selectedDate)
                }

                Text("Tap a day to show it in the timeline.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }

    private func weekBlock(profile: Profile, payload: NapsPayload, selectedDate: String) -> some View {
        let stats = NapHelpers.childWeekStats(
            profileId: profile.id,
            naps: payload.weekLogs,
            weekDates: payload.weekDates,
            todayLocalDate: payload.localDate,
            timezone: timezone,
            now: now
        )
        let color = HubTheme.profileColor(profile.color)
        // Each day's logs, found once. The heatmap used to look them up again for every one of its
        // 42 cells, which made this card the slowest thing on the page to draw.
        let logsByDay = Dictionary(uniqueKeysWithValues: payload.weekDates.map { localDate in
            (localDate, NapHelpers.logsForDate(profileId: profile.id, in: payload.weekLogs, localDate: localDate, timezone: timezone))
        })

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(profile.name).font(.subheadline.weight(.bold))
            }
            Text("Avg \(NapHelpers.formatAverageNapCount(stats.avgNapsPerDay)) sleeps/day · \(NapHelpers.formatDuration(minutes: Int(stats.avgMinutesPerDay.rounded())))/day")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)

            HStack(spacing: 4) {
                ForEach(stats.days, id: \.localDate) { day in
                    let isSelected = day.localDate == selectedDate
                    let isToday = day.localDate == payload.localDate
                    Button {
                        selectedPatternDate = day.localDate
                    } label: {
                        VStack(spacing: 4) {
                            Text(DateHelpers.formatLocalDate(day.localDate, timezone: timezone, pattern: "EEE"))
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                            Text("\(day.napCount + day.nightCount)")
                                .font(.title3.weight(.semibold))
                            Text(day.napCount + day.nightCount == 0 ? "—" : NapHelpers.formatDuration(minutes: day.totalMinutes))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? HubTheme.sage.opacity(0.12) : (isToday ? HubTheme.tileQuiet : Color.clear))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? HubTheme.sage : (isToday ? HubTheme.sage.opacity(0.5) : HubTheme.line), lineWidth: isSelected ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 3) {
                ForEach(NapTimelineHelpers.heatmapBlocks, id: \.label) { block in
                    HStack(spacing: 3) {
                        Text(block.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .frame(width: 44, alignment: .leading)
                        ForEach(payload.weekDates, id: \.self) { localDate in
                            let dayLogs = logsByDay[localDate] ?? []
                            let active = dayLogs.contains { NapTimelineHelpers.overlapsHeatmapBlock(nap: $0, localDate: localDate, timezone: timezone, block: block, now: now) }
                            Button { selectedPatternDate = localDate } label: {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(active ? color.opacity(localDate == selectedDate ? 0.72 : 0.42) : HubTheme.tileQuiet)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 22)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(localDate == selectedDate ? HubTheme.sage : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Text("Week total: \(NapHelpers.daySummary(napCount: stats.totalNaps, nightCount: stats.totalNights, totalMinutes: stats.totalMinutes))")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
        }
    }

    // MARK: Helpers

    private func shiftPatternDate(payload: NapsPayload, delta: Int) {
        let selectedDate = selectedPatternDate ?? payload.localDate
        guard let index = payload.weekDates.firstIndex(of: selectedDate) else { return }
        let nextIndex = index + delta
        guard payload.weekDates.indices.contains(nextIndex) else { return }
        selectedPatternDate = payload.weekDates[nextIndex]
    }

    private var timezone: TimeZone {
        TimeZone(identifier: appState.household?.timezone ?? "") ?? .current
    }

    private func sleepLogs(from payload: NapsPayload) -> [NapLog] {
        var seen = Set<String>()
        return (payload.weekLogs + payload.naps).filter { seen.insert($0.id).inserted }
    }

    private func timelineFrame(leftPercent: Double, widthPercent: Double, trackWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let left = min(max(leftPercent, 0), 100)
        let width = min(max(widthPercent, 0), 100 - left)
        let x = trackWidth * left / 100
        let rawWidth = trackWidth * width / 100
        let maxWidth = max(0, trackWidth - x)
        return (x, min(rawWidth, maxWidth))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let version = writeVersion
        do {
            let fresh = try await appState.api.fetchNaps()
            // A write finished while this was in flight, so what came back may predate it. That
            // write started its own reload, which will bring the page up to date.
            guard version == writeVersion else { return }
            payload = fresh
            errorMessage = nil
            await SleepLiveActivityManager.sync(logs: sleepLogs(from: fresh), children: fresh.childProfiles)
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    /// Runs one sleep write and shows its result at once: the server answers with the entry it
    /// changed, so there is nothing to wait for beyond that single request. The dashboard (reminders,
    /// Today cards) and a full reload catch up in the background. Returns a message for the caller
    /// to show when the write fails, or nil when it succeeded.
    @discardableResult
    private func commit(removing removedId: String? = nil, _ write: () async throws -> NapLog?) async -> String? {
        do {
            let log = try await write()
            writeVersion += 1
            if let removedId { payload?.remove(id: removedId) }
            if let log { payload?.apply(log) }
            errorMessage = nil
            if let payload {
                await SleepLiveActivityManager.sync(logs: sleepLogs(from: payload), children: payload.childProfiles)
            }
            if log == nil && removedId == nil {
                // An older server doesn't send the entry back, so reload before showing anything.
                await load()
            }
            reconcileInBackground()
            return nil
        } catch {
            return error.userFacingMessage ?? "That didn't finish. Try again."
        }
    }

    /// For the buttons on the page itself: a failure shows at the top of the page.
    private func run(_ write: () async throws -> NapLog?) async {
        if let message = await commit(write) {
            errorMessage = message
        }
    }

    private func reconcileInBackground() {
        Task {
            async let page: Void = load()
            await appState.refreshDashboard()
            await page
        }
    }

    private func startNap(profileId: String) async {
        await run { try await appState.api.startNap(profileId: profileId) }
    }

    private func startNightSleep(profileId: String) async {
        await run { try await appState.api.startNightSleep(profileId: profileId) }
    }

    private func endNap(napId: String) async {
        await run { try await appState.api.endNap(napId: napId) }
    }

    private func createNap(profileId: String, startedAt: Date, endedAt: Date?) async -> String? {
        await commit { try await appState.api.createNap(profileId: profileId, startedAt: startedAt, endedAt: endedAt) }
    }

    private func createNightSleep(profileId: String, fellAsleepAt: Date, wokeUpAt: Date?) async -> String? {
        await commit { try await appState.api.createNightSleep(profileId: profileId, fellAsleepAt: fellAsleepAt, wokeUpAt: wokeUpAt) }
    }

    private func updateNap(id: String, startedAt: Date, endedAt: Date?) async -> String? {
        await commit { try await appState.api.updateNap(id: id, startedAt: startedAt, endedAt: endedAt) }
    }

    private func deleteNap(id: String) async -> String? {
        await commit(removing: id) {
            try await appState.api.deleteNap(id: id)
            return nil
        }
    }
}
