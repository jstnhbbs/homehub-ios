import SwiftUI

struct NapsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var payload: NapsPayload?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var now = Date.now
    @State private var selectedPatternDate: String?

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
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
                        logHeader
                        quickLogSection(payload)
                        bedtimeSection(payload)
                        manualEntrySection(payload)
                        todayHistorySection(payload)
                        patternsSection(payload)
                    }
                }
                .padding(24)
            }
            .background(HubTheme.surface)
            .navigationTitle("Sleep")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .onReceive(timer) { date in
                now = date
            }
        }
    }

    @ViewBuilder
    private var logHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log")
                .font(.caption.weight(.heavy))
                .foregroundStyle(HubTheme.sage)
                .textCase(.uppercase)
            Text("Track sleep")
                .font(.title2.weight(.semibold))
        }
    }

    @ViewBuilder
    private func quickLogSection(_ payload: NapsPayload) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Nap timer", systemImage: "moon.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)

                if payload.childProfiles.isEmpty {
                    EmptyStateView(text: "Add a child profile in Settings to start logging sleep.")
                } else {
                    ForEach(payload.childProfiles) { profile in
                        NapChildRowView(
                            profile: profile,
                            activeNap: NapHelpers.activeNap(for: profile.id, in: payload.naps),
                            timezone: TimeZone(identifier: appState.household?.timezone ?? "") ?? .current,
                            now: now,
                            emptyLabel: "No active nap",
                            activeLabel: "Asleep since",
                            startLabel: "Start nap",
                            endLabel: "End nap"
                        ) {
                            await startNap(profileId: profile.id)
                        } endAction: {
                            if let nap = NapHelpers.activeNap(for: profile.id, in: payload.naps) {
                                await endNap(napId: nap.id)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bedtimeSection(_ payload: NapsPayload) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Bedtime", systemImage: "bed.double.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)

                Text("Start bedtime when they fall asleep, then log wake up in the morning.")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(HubTheme.muted)

                if payload.childProfiles.isEmpty {
                    EmptyStateView(text: "Add a child profile in Settings to start logging sleep.")
                } else {
                    ForEach(payload.childProfiles) { profile in
                        NapChildRowView(
                            profile: profile,
                            activeNap: NapHelpers.activeNight(for: profile.id, in: payload.weekLogs),
                            timezone: TimeZone(identifier: appState.household?.timezone ?? "") ?? .current,
                            now: now,
                            emptyLabel: "No active bedtime",
                            activeLabel: "In bed since",
                            startLabel: "Start bedtime",
                            endLabel: "Log wake up"
                        ) {
                            await startNightSleep(profileId: profile.id)
                        } endAction: {
                            if let night = NapHelpers.activeNight(for: profile.id, in: payload.weekLogs) {
                                await endNap(napId: night.id)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func manualEntrySection(_ payload: NapsPayload) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 16) {
                ManualNapFormView(
                    childProfiles: payload.childProfiles,
                    timezone: TimeZone(identifier: appState.household?.timezone ?? "") ?? .current
                ) { profileId, startedAt, endedAt in
                    await createNap(profileId: profileId, startedAt: startedAt, endedAt: endedAt)
                }

                ManualNightSleepFormView(
                    childProfiles: payload.childProfiles,
                    timezone: TimeZone(identifier: appState.household?.timezone ?? "") ?? .current
                ) { profileId, fellAsleepAt, wokeUpAt in
                    await createNightSleep(profileId: profileId, fellAsleepAt: fellAsleepAt, wokeUpAt: wokeUpAt)
                }
            }
        }
    }

    @ViewBuilder
    private func todayHistorySection(_ payload: NapsPayload) -> some View {
        let todayLogs = NapHelpers.logsForDate(
            profileId: nil,
            in: payload.weekLogs,
            localDate: payload.localDate,
            timezone: timezone,
            now: now
        ).sorted { $0.startedAt < $1.startedAt }

        if todayLogs.isEmpty {
            EmptyView()
        } else {
            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's sleep")
                        .font(.title3.weight(.semibold))
                    Text("Tap Edit on any entry to change start or end times after logging.")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(HubTheme.muted)

                    ForEach(todayLogs) { nap in
                        if let profile = payload.childProfiles.first(where: { $0.id == nap.profileId }) {
                            NapHistoryRowView(
                                nap: nap,
                                profile: profile,
                                timezone: timezone,
                                now: now,
                                endAction: nap.endedAt == nil ? { await endNap(napId: nap.id) } : nil,
                                saveAction: { startedAt, endedAt in
                                    await updateNap(id: nap.id, startedAt: startedAt, endedAt: endedAt)
                                },
                                deleteAction: { await deleteNap(id: nap.id) }
                            )
                            .id("\(nap.id)-\(nap.startedAt.timeIntervalSince1970)-\(nap.endedAt?.timeIntervalSince1970 ?? 0)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func patternsSection(_ payload: NapsPayload) -> some View {
        let weekStartsOn = appState.household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn
        let dayLabels = WeekStart.weekdayLabels(weekStartsOn: weekStartsOn)
        let selectedDate = selectedPatternDate ?? payload.localDate
        let selectedIndex = payload.weekDates.firstIndex(of: selectedDate) ?? 0
        let selectedDayLogs = NapHelpers.logsForDate(
            profileId: nil,
            in: payload.weekLogs,
            localDate: selectedDate,
            timezone: timezone
        )

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Patterns")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HubTheme.sage)
                    .textCase(.uppercase)
                Text("Sleep rhythms")
                    .font(.title2.weight(.semibold))
                Text("Tap a day in the grid to explore timing, wake windows, and weekly trends.")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }

            HubCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This week")
                        .font(.title3.weight(.semibold))
                    if let start = payload.weekDates.first, let end = payload.weekDates.last {
                        Text("\(DateHelpers.formatLocalDate(start, timezone: timezone, pattern: "MMM d")) – \(DateHelpers.formatLocalDate(end, timezone: timezone, pattern: "MMM d"))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }

                    ForEach(payload.childProfiles) { profile in
                        let stats = NapHelpers.childWeekStats(
                            profileId: profile.id,
                            naps: payload.weekLogs,
                            weekDates: payload.weekDates,
                            todayLocalDate: payload.localDate,
                            timezone: timezone,
                            now: now
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Circle().fill(HubTheme.profileColor(profile.color)).frame(width: 12, height: 12)
                                Text(profile.name).font(.subheadline.weight(.bold))
                                Text("Avg \(NapHelpers.formatAverageNapCount(stats.avgNapsPerDay)) naps/day · \(NapHelpers.formatDuration(minutes: Int(stats.avgMinutesPerDay.rounded())))/day")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(HubTheme.muted)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(stats.days.enumerated()), id: \.element.localDate) { index, day in
                                        Button {
                                            selectedPatternDate = day.localDate
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(dayLabels[index]).font(.caption2.weight(.heavy)).foregroundStyle(HubTheme.muted)
                                                Text(DateHelpers.formatLocalDate(day.localDate, timezone: timezone, pattern: "MMM d"))
                                                    .font(.caption2.weight(.bold)).foregroundStyle(HubTheme.muted)
                                                Text("\(day.napCount)").font(.title3.weight(.semibold))
                                                Text(day.napCount == 0 ? "—" : NapHelpers.formatDuration(minutes: day.totalMinutes))
                                                    .font(.caption2.weight(.bold)).foregroundStyle(HubTheme.muted)
                                            }
                                            .frame(width: 84, alignment: .leading)
                                            .padding(12)
                                            .background(day.localDate == selectedDate ? HubTheme.sage.opacity(0.12) : (day.localDate == payload.localDate ? HubTheme.tileQuiet : Color.clear))
                                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(day.localDate == selectedDate ? HubTheme.sage : (day.localDate == payload.localDate ? HubTheme.sage.opacity(0.5) : HubTheme.line), lineWidth: day.localDate == selectedDate ? 2 : 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Text("Week heatmap")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                                .textCase(.uppercase)

                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Color.clear.frame(width: 48, height: 1)
                                        ForEach(payload.weekDates, id: \.self) { localDate in
                                            Text(DateHelpers.formatLocalDate(localDate, timezone: timezone, pattern: "EEE"))
                                                .font(.caption2.weight(.heavy))
                                                .foregroundStyle(HubTheme.muted)
                                                .frame(width: 36)
                                        }
                                    }
                                    ForEach(NapTimelineHelpers.heatmapBlocks, id: \.label) { block in
                                        HStack(spacing: 4) {
                                            Text(block.label)
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(HubTheme.muted)
                                                .frame(width: 48, alignment: .leading)
                                            ForEach(payload.weekDates, id: \.self) { localDate in
                                                let profileDayLogs = NapHelpers.logsForDate(
                                                    profileId: profile.id,
                                                    in: payload.weekLogs,
                                                    localDate: localDate,
                                                    timezone: timezone
                                                )
                                                let active = profileDayLogs.contains { NapTimelineHelpers.overlapsHeatmapBlock(nap: $0, localDate: localDate, timezone: timezone, block: block, now: now) }
                                                Button { selectedPatternDate = localDate } label: {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(active ? HubTheme.profileColor(profile.color).opacity(localDate == selectedDate ? 0.72 : 0.42) : HubTheme.tileQuiet)
                                                        .frame(width: 36, height: 28)
                                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(localDate == selectedDate ? HubTheme.sage : Color.clear, lineWidth: 1))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }

                            Text("Week total: \(stats.totalNaps) naps · \(NapHelpers.formatDuration(minutes: stats.totalMinutes))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }
                    }
                }
            }

            HubCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day timeline")
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

                    ForEach(payload.childProfiles) { profile in
                        let profileDayLogs = NapHelpers.logsForDate(
                            profileId: profile.id,
                            in: payload.weekLogs,
                            localDate: selectedDate,
                            timezone: timezone
                        )
                        let bars = NapTimelineHelpers.dayTimelineBars(naps: profileDayLogs, localDate: selectedDate, timezone: timezone, now: now)
                        let gaps = NapTimelineHelpers.awakeGaps(naps: profileDayLogs, localDate: selectedDate, timezone: timezone)
                        let totalMinutes = profileDayLogs.reduce(0) { $0 + NapHelpers.durationMinutes(startedAt: $1.startedAt, endedAt: $1.endedAt, now: now) }
                        let napCount = profileDayLogs.filter { $0.kind == "nap" }.count
                        let nightCount = profileDayLogs.filter { $0.kind == "night" }.count

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle().fill(HubTheme.profileColor(profile.color)).frame(width: 12, height: 12)
                                Text(profile.name).font(.subheadline.weight(.bold))
                                Text(NapHelpers.daySummary(napCount: napCount, nightCount: nightCount, totalMinutes: totalMinutes))
                                    .font(.caption.weight(.bold)).foregroundStyle(HubTheme.muted)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(HubTheme.tileQuiet)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(HubTheme.line))

                                    ForEach(gaps) { gap in
                                        Text(gap.widthPercent > 8 ? gap.label : "")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(HubTheme.muted)
                                            .frame(width: geometry.size.width * gap.widthPercent / 100)
                                            .offset(x: geometry.size.width * gap.leftPercent / 100)
                                    }

                                    ForEach(bars) { bar in
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(HubTheme.profileColor(profile.color))
                                            .frame(width: max(geometry.size.width * bar.widthPercent / 100, 24))
                                            .offset(x: geometry.size.width * bar.leftPercent / 100)
                                            .overlay {
                                                if bar.widthPercent > 10 {
                                                    Text(bar.durationLabel)
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(.white)
                                                        .offset(x: geometry.size.width * bar.leftPercent / 100)
                                                }
                                            }
                                    }

                                    if bars.isEmpty {
                                        Text("No sleep logged")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(HubTheme.muted)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .frame(height: 56)
                        }
                    }

                    Divider()

                    Text(selectedDate == payload.localDate ? "Today's sleep" : "Sleep this day")
                        .font(.headline.weight(.semibold))

                    if selectedDayLogs.isEmpty {
                        Text("No sleep logged on this day.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(selectedDayLogs) { nap in
                            if let profile = payload.childProfiles.first(where: { $0.id == nap.profileId }) {
                                NapHistoryRowView(
                                    nap: nap,
                                    profile: profile,
                                    timezone: timezone,
                                    now: now,
                                    endAction: nap.endedAt == nil ? { await endNap(napId: nap.id) } : nil,
                                    saveAction: { startedAt, endedAt in
                                        await updateNap(id: nap.id, startedAt: startedAt, endedAt: endedAt)
                                    },
                                    deleteAction: { await deleteNap(id: nap.id) }
                                )
                                .id("\(nap.id)-\(nap.startedAt.timeIntervalSince1970)-\(nap.endedAt?.timeIntervalSince1970 ?? 0)")
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: payload.localDate) { _, newValue in
            selectedPatternDate = newValue
        }
    }

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

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            payload = try await appState.api.fetchNaps()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startNap(profileId: String) async {
        do {
            try await appState.api.startNap(profileId: profileId)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createNap(profileId: String, startedAt: Date, endedAt: Date?) async {
        do {
            try await appState.api.createNap(profileId: profileId, startedAt: startedAt, endedAt: endedAt)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startNightSleep(profileId: String) async {
        do {
            try await appState.api.startNightSleep(profileId: profileId)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createNightSleep(profileId: String, fellAsleepAt: Date, wokeUpAt: Date?) async {
        do {
            try await appState.api.createNightSleep(profileId: profileId, fellAsleepAt: fellAsleepAt, wokeUpAt: wokeUpAt)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endNap(napId: String) async {
        do {
            try await appState.api.endNap(napId: napId)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateNap(id: String, startedAt: Date, endedAt: Date?) async {
        do {
            try await appState.api.updateNap(id: id, startedAt: startedAt, endedAt: endedAt)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteNap(id: String) async {
        do {
            try await appState.api.deleteNap(id: id)
            await appState.refreshDashboard()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ManualNapFormView: View {
    let childProfiles: [Profile]
    let timezone: TimeZone
    let onSubmit: (String, Date, Date?) async -> Void

    @State private var selectedProfileId: String
    @State private var startedAt: Date
    @State private var endedAt: Date?
    @State private var includeEndTime = false

    init(
        childProfiles: [Profile],
        timezone: TimeZone,
        onSubmit: @escaping (String, Date, Date?) async -> Void
    ) {
        self.childProfiles = childProfiles
        self.timezone = timezone
        self.onSubmit = onSubmit
        _selectedProfileId = State(initialValue: childProfiles.first?.id ?? "")
        _startedAt = State(initialValue: Date.now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add nap manually")
                .font(.title3.weight(.semibold))

            if childProfiles.isEmpty {
                Text("Add a child profile in Settings to log naps.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)
            } else {
                Picker("Child", selection: $selectedProfileId) {
                    ForEach(childProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }

                DatePicker(
                    "Start time",
                    selection: $startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle("Set end time", isOn: $includeEndTime)

                if includeEndTime {
                    DatePicker(
                        "End time",
                        selection: Binding(
                            get: { endedAt ?? startedAt.addingTimeInterval(3600) },
                            set: { endedAt = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Button("Add nap") {
                    Task {
                        await onSubmit(
                            selectedProfileId,
                            startedAt,
                            includeEndTime ? (endedAt ?? startedAt.addingTimeInterval(3600)) : nil
                        )
                    }
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                .disabled(selectedProfileId.isEmpty)
            }
        }
    }
}

private struct ManualNightSleepFormView: View {
    let childProfiles: [Profile]
    let timezone: TimeZone
    let onSubmit: (String, Date, Date?) async -> Void

    @State private var selectedProfileId: String
    @State private var fellAsleepAt: Date
    @State private var wokeUpAt: Date
    @State private var includeWakeTime = false

    init(
        childProfiles: [Profile],
        timezone: TimeZone,
        onSubmit: @escaping (String, Date, Date?) async -> Void
    ) {
        self.childProfiles = childProfiles
        self.timezone = timezone
        self.onSubmit = onSubmit
        _selectedProfileId = State(initialValue: childProfiles.first?.id ?? "")
        _fellAsleepAt = State(initialValue: Date.now)
        _wokeUpAt = State(initialValue: Date.now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log night sleep")
                .font(.title3.weight(.semibold))

            if childProfiles.isEmpty {
                Text("Add a child profile in Settings to log sleep.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)
            } else {
                Picker("Child", selection: $selectedProfileId) {
                    ForEach(childProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }

                DatePicker(
                    "Fell asleep",
                    selection: $fellAsleepAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle("Set wake time", isOn: $includeWakeTime)

                if includeWakeTime {
                    DatePicker(
                        "Woke up",
                        selection: $wokeUpAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } else {
                    Text("Leave unset if they're still asleep. Add the wake time later.")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }

                Button(includeWakeTime ? "Add night sleep" : "Start bedtime") {
                    Task {
                        await onSubmit(
                            selectedProfileId,
                            fellAsleepAt,
                            includeWakeTime ? wokeUpAt : nil
                        )
                    }
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                .disabled(selectedProfileId.isEmpty)
            }
        }
    }
}

private struct NapChildRowView: View {
    let profile: Profile
    let activeNap: NapLog?
    let timezone: TimeZone
    let now: Date
    let emptyLabel: String
    let activeLabel: String
    let startLabel: String
    let endLabel: String
    let startAction: () async -> Void
    let endAction: () async -> Void

    init(
        profile: Profile,
        activeNap: NapLog?,
        timezone: TimeZone,
        now: Date,
        emptyLabel: String = "No active nap",
        activeLabel: String = "Asleep since",
        startLabel: String = "Start nap",
        endLabel: String = "End nap",
        startAction: @escaping () async -> Void,
        endAction: @escaping () async -> Void
    ) {
        self.profile = profile
        self.activeNap = activeNap
        self.timezone = timezone
        self.now = now
        self.emptyLabel = emptyLabel
        self.activeLabel = activeLabel
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.startAction = startAction
        self.endAction = endAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(HubTheme.profileColor(profile.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.subheadline.weight(.bold))
                if let activeNap {
                    Text("\(activeLabel) \(DateHelpers.timeString(activeNap.startedAt, timezone: timezone)) · \(durationLabel(for: activeNap))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                } else {
                    Text(emptyLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }

            Spacer()

            if activeNap != nil {
                Button(endLabel) {
                    Task { await endAction() }
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
            } else {
                Button(startLabel) {
                    Task { await startAction() }
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
            }
        }
        .padding(12)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func durationLabel(for nap: NapLog) -> String {
        NapHelpers.formatDuration(
            minutes: NapHelpers.durationMinutes(
                startedAt: nap.startedAt,
                endedAt: nap.endedAt,
                now: now
            )
        )
    }
}

private struct NapHistoryRowView: View {
    let nap: NapLog
    let profile: Profile
    let timezone: TimeZone
    let now: Date
    let endAction: (() async -> Void)?
    let saveAction: (Date, Date?) async -> Void
    let deleteAction: () async -> Void

    @State private var isEditing = false
    @State private var startedAt: Date
    @State private var endedAt: Date?
    @State private var includeEndTime: Bool

    init(
        nap: NapLog,
        profile: Profile,
        timezone: TimeZone,
        now: Date,
        endAction: (() async -> Void)?,
        saveAction: @escaping (Date, Date?) async -> Void,
        deleteAction: @escaping () async -> Void
    ) {
        self.nap = nap
        self.profile = profile
        self.timezone = timezone
        self.now = now
        self.endAction = endAction
        self.saveAction = saveAction
        self.deleteAction = deleteAction
        _startedAt = State(initialValue: nap.startedAt)
        _endedAt = State(initialValue: nap.endedAt)
        _includeEndTime = State(initialValue: nap.endedAt != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(HubTheme.profileColor(profile.color))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.subheadline.weight(.bold))
                    if !isEditing {
                        Text("\(sleepKindLabel) · \(DateHelpers.timeString(nap.startedAt, timezone: timezone)) – \(endLabel) · \(durationLabel)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                Spacer()

                if !isEditing {
                    if let endAction {
                        Button(nap.kind == "night" ? "Wake up" : "End") {
                            Task { await endAction() }
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .mini))
                    }

                    Button("Edit") {
                        startedAt = nap.startedAt
                        endedAt = nap.endedAt
                        includeEndTime = nap.endedAt != nil
                        isEditing = true
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.sage)

                    Button("Delete", role: .destructive) {
                        Task { await deleteAction() }
                    }
                    .font(.caption.weight(.bold))
                }
            }

            if isEditing {
                DatePicker(
                    nap.kind == "night" ? "Fell asleep" : "Start time",
                    selection: $startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Toggle(nap.kind == "night" ? "Set wake time" : "Set end time", isOn: $includeEndTime)

                if includeEndTime {
                    DatePicker(
                        nap.kind == "night" ? "Woke up" : "End time",
                        selection: Binding(
                            get: { endedAt ?? startedAt.addingTimeInterval(3600) },
                            set: { endedAt = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } else {
                    Text("Leave unset if still asleep or in progress.")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }

                HStack {
                    Button("Save") {
                        Task {
                            await saveAction(startedAt, includeEndTime ? endedAt : nil)
                            isEditing = false
                        }
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .primary, size: .small))

                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var sleepKindLabel: String {
        nap.kind == "night" ? "Night" : "Nap"
    }

    private var endLabel: String {
        guard let endedAt = nap.endedAt else {
            return nap.kind == "night" ? "Still asleep" : "In progress"
        }
        return DateHelpers.timeString(endedAt, timezone: timezone)
    }

    private var durationLabel: String {
        NapHelpers.formatDuration(
            minutes: NapHelpers.durationMinutes(
                startedAt: nap.startedAt,
                endedAt: nap.endedAt,
                now: now
            )
        )
    }
}
