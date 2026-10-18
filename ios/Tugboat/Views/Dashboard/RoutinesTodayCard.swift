import SwiftUI

/// The Routines card at all three sizes.
///
/// Small is a glance: how many steps are done, what is next, and a progress ring for each child.
/// Medium has a row for each child with their next step, which can be ticked off from the row. Large has a
/// column for each child with all of their steps, current part of the day first, each one tickable.
struct RoutinesTodayCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    @State private var celebration: String?

    private var timezone: TimeZone { TimeZone(identifier: dashboard.household.timezone) ?? .current }

    private var summary: RoutineCardSummary {
        let hour = DateHelpers.gregorian(in: timezone).component(.hour, from: Date())
        return RoutineCardSummary(
            groups: RoutineProgressGroup.groups(profiles: dashboard.profiles, steps: dashboard.routineSteps),
            period: RoutineCardSummary.period(hour: hour)
        )
    }

    private func streak(for group: RoutineProgressGroup) -> RoutineStreak? {
        let profileId: String? = group.id == "household" ? nil : group.id
        return dashboard.routineStreaks.first { $0.profileId == profileId }
    }

    var body: some View {
        TodayCardFrame(card: .routines, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
        .overlay(alignment: .top) {
            if size != .small, let celebration {
                StreakBanner(text: celebration)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 6)
            }
        }
        .onAppear { celebrateMilestones() }
        .onChange(of: dashboard.routineStreaks) { _, _ in celebrateMilestones() }
    }

    // MARK: Small

    private var small: some View {
        let summary = summary
        return TodayCardSmallBody(card: .routines) {
            VStack(alignment: .leading, spacing: 4) {
                TodayCardHeadline(
                    headline: summary.headline,
                    caption: summary.caption { RoutineGlyphs.display(for: $0.label).label }
                )
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(summary.groups.prefix(4)) { group in
                        RoutineRing(group: group, diameter: DashboardMetrics.scaled(30, .body))
                    }
                }
            }
        }
    }

    // MARK: Medium

    @ViewBuilder
    private var medium: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            if summary.isEmpty {
                TodayCardEmptyNote(text: "Add a morning or bedtime routine.")
            } else {
                WholeRowsGrid(
                    items: summary.groups,
                    minimumColumnWidth: 175,
                    maxColumns: 3,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.routines) },
                    allowsCompactRows: true
                ) { group, _ in
                    RoutineNextStepRow(group: group, streak: streak(for: group), summary: summary, localDate: dashboard.localDate)
                }
            }
        }
    }

    // MARK: Large

    @ViewBuilder
    private var large: some View {
        let summary = summary
        VStack(alignment: .leading, spacing: 8) {
            TodayCardSummaryLine(text: summary.line)
            if summary.isEmpty {
                TodayCardEmptyNote(text: "Add a morning or bedtime routine.")
            } else {
                GeometryReader { geo in
                    // As many children side by side as fit; the rest are one tap away.
                    let columns = max(1, min(3, Int((geo.size.width + 10) / 160)))
                    let shown = Array(summary.groups.prefix(columns))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(shown) { group in
                                RoutineChildColumn(
                                    group: group,
                                    streak: streak(for: group),
                                    summary: summary,
                                    localDate: dashboard.localDate
                                )
                            }
                        }
                    }
                    .todayCardMore(count: summary.groups.count - shown.count) { openHubDestination(.routines) }
                }
            }
        }
    }

    // MARK: Milestones

    /// Shows a banner the first time a child reaches a streak milestone on a given day.
    private func celebrateMilestones() {
        guard size != .small else { return }
        for group in summary.groups {
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

// MARK: - Pieces

/// Progress as a ring around a child's avatar.
struct RoutineRing: View {
    let group: RoutineProgressGroup
    let diameter: CGFloat

    var body: some View {
        let tint = HubTheme.profileColor(group.color)
        let ring: CGFloat = diameter < 44 ? 3 : 4
        let inset: CGFloat = diameter < 44 ? 3 : 5
        ZStack {
            Circle().stroke(tint.opacity(DashboardOutline.resting), lineWidth: ring)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.name), \(group.completedCount) of \(group.totalCount) routine steps complete")
    }
}

struct StreakBanner: View {
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

/// A child's row on the Medium card: their ring and name, the step they are on, and a button that ticks it.
private struct RoutineNextStepRow: View {
    @EnvironmentObject private var appState: AppState
    let group: RoutineProgressGroup
    var streak: RoutineStreak?
    let summary: RoutineCardSummary
    let localDate: String

    @State private var isWorking = false

    private var next: RoutineStepRow? { summary.ordered(group.steps).first { !$0.completed } }

    private var subtitle: String {
        guard let next else { return "All set" }
        let display = RoutineGlyphs.display(for: next.label)
        let more = group.remainingSteps.count - 1
        return more > 0 ? "\(display.glyph) \(display.label) +\(more)" : "\(display.glyph) \(display.label)"
    }

    var body: some View {
        let tint = HubTheme.profileColor(group.color)
        DashboardRow(title: group.name, subtitle: subtitle, tint: tint) {
            RoutineRing(group: group, diameter: 28)
        } trailing: {
            HStack(spacing: 4) {
                if let days = streak?.current, days >= StreakHelpers.minimumToShow {
                    StreakChip(days: days)
                }
                if let next {
                    Button { Task { await tick(next) } } label: {
                        Image(systemName: isWorking ? "hourglass" : "circle")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(HubTheme.profileText(group.color))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityLabel("Mark \(RoutineGlyphs.display(for: next.label).label) done for \(group.name)")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HubTheme.accentText)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func tick(_ step: RoutineStepRow) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.toggleRoutineStep(stepId: step.id, localDate: localDate, completed: true)
        } catch {
            appState.report(error)
        }
    }
}

/// One child's column on the Large card: who they are and how far along, then every step, tickable.
private struct RoutineChildColumn: View {
    @Environment(\.openHubDestination) private var openHubDestination
    let group: RoutineProgressGroup
    var streak: RoutineStreak?
    let summary: RoutineCardSummary
    let localDate: String

    var body: some View {
        let steps = summary.ordered(group.steps)
        // Say which part of the day a step belongs to once a child has steps in more than one.
        let spansPeriods = Set(group.steps.map(\.period)).count > 1
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoutineRing(group: group, diameter: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.name)
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)
                    Text(group.isComplete ? "All set" : "\(group.completedCount)/\(group.totalCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.profileText(group.color))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                if let days = streak?.current, days >= StreakHelpers.minimumToShow {
                    StreakChip(days: days)
                }
            }
            WholeRowsGrid(
                items: steps,
                minimumColumnWidth: 120,
                maxColumns: 1,
                itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                onMore: { openHubDestination(.routines) },
                allowsCompactRows: true
            ) { step, _ in
                RoutineStepCheckRow(step: step, localDate: localDate, subtitle: spansPeriods ? step.period.label : nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A routine step on the Large card: tap to tick it off, tap again to undo.
private struct RoutineStepCheckRow: View {
    @EnvironmentObject private var appState: AppState
    let step: RoutineStepRow
    let localDate: String
    var subtitle: String?

    @State private var isChecked: Bool
    @State private var isWorking = false

    init(step: RoutineStepRow, localDate: String, subtitle: String?) {
        self.step = step
        self.localDate = localDate
        self.subtitle = subtitle
        _isChecked = State(initialValue: step.completed)
    }

    var body: some View {
        let display = RoutineGlyphs.display(for: step.label)
        Button { Task { await toggle() } } label: {
            DashboardRow(title: display.label, subtitle: subtitle, isDone: isChecked) {
                Text(display.glyph).font(.title3)
            } trailing: {
                if isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    DashboardCheckMarker(isChecked: isChecked)
                }
            }
        }
        .buttonStyle(.plain)
        // Something outside this row (a widget, another device) can change it; follow the data.
        .onChange(of: step.completed) { _, completed in isChecked = completed }
        .disabled(isWorking)
        .onChange(of: step.completed) { _, completed in isChecked = completed }
        .accessibilityValue(isChecked ? "Done" : "Not done")
        .accessibilityAddTraits(.isToggle)
    }

    private func toggle() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let wanted = !isChecked
        isChecked = wanted
        do {
            try await appState.toggleRoutineStep(stepId: step.id, localDate: localDate, completed: wanted)
        } catch {
            isChecked = !wanted
            appState.report(error)
        }
    }
}
