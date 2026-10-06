import SwiftUI
import UIKit

struct RoutinesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = RoutinesViewModel()
    @State private var activeRoutineEditor: RoutineEditorPresentation?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if let error = viewModel.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        routinesContent(columns: [GridItem(.flexible(), alignment: .top)])
                    }
                }
            } else {
                wideContent
            }
        }
        .sheet(item: $activeRoutineEditor) { editor in
            RoutineEditorSheet(
                editor: editor,
                routines: viewModel.routines,
                profiles: viewModel.profiles,
                viewModel: viewModel
            )
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    routinesContent(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)])
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func routinesContent(columns: [GridItem]) -> some View {
        if viewModel.isLoading && viewModel.routines.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        } else if viewModel.routines.isEmpty {
            EmptyStateView(text: "Your first routine will appear here.")
        } else {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.groups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        // A name over each person's routines when there is more than one group to tell apart.
                        if viewModel.groups.count > 1 {
                            GroupHeading(group: group)
                        }
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(group.routines) { routine in
                                RoutineCard(routine: routine, viewModel: viewModel) {
                                    activeRoutineEditor = .edit(routine.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            if horizontalSizeClass != .compact {
                Text("Routines")
                    .font(HubTheme.pageTitle)
            }
            Spacer()
            if viewModel.canManage {
                Button {
                    activeRoutineEditor = .add(UUID())
                } label: {
                    Label("Add Routine", systemImage: "plus")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
            }
        }
    }
}

private struct GroupHeading: View {
    let group: RoutineGroup

    var body: some View {
        HStack(spacing: 10) {
            if let profile = group.profile {
                ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color, size: 32)
            }
            Text(group.profile?.name ?? "Everyone")
                .font(.title3.weight(.semibold))
        }
        .accessibilityAddTraits(.isHeader)
    }
}

private struct RoutineCard: View {
    let routine: Routine
    @ObservedObject var viewModel: RoutinesViewModel
    let onEdit: () -> Void

    private var meta: (label: String, icon: String, color: Color) {
        switch routine.period {
        case .morning: ("Morning", "sun.max.fill", HubTheme.sunSoft)
        case .afternoon: ("After school", "sunset.fill", Color(red: 0.95, green: 0.88, blue: 0.85))
        case .evening: ("Bedtime", "moon.fill", Color(red: 0.88, green: 0.91, blue: 0.96))
        }
    }

    private var runsToday: Bool {
        RoutineDays.runsOn(routine.days, localDate: viewModel.localDate)
    }

    /// "ADA · MORNING", with the days after it when the routine doesn't run every day.
    private func headerLabel(profile: Profile?) -> String {
        var parts = ["\(profile?.name ?? "Everyone") · \(meta.label)"]
        if RoutineDays.parse(routine.days) != RoutineDays.everyDay {
            parts.append(RoutineDays.summary(routine.days))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let profile = viewModel.profile(for: routine.profileId)
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        // Whose routine this is, in words as well as colour: a family with several
                        // children has several "Morning" cards that otherwise look alike.
                        HStack(spacing: 6) {
                            Circle()
                                .fill(HubTheme.profileColor(profile?.color))
                                .frame(width: 8, height: 8)
                            Text(headerLabel(profile: profile).uppercased())
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                                .lineLimit(1)
                        }
                        Text(routine.name)
                            .font(.title2.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: meta.icon)
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(meta.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                let pending = viewModel.pendingSteps(for: routine)

                if !runsToday {
                    // Not on today: nothing to tap, and when it next runs is the useful part.
                    VStack(spacing: 4) {
                        Text("Not on today")
                            .font(.subheadline.weight(.bold))
                        Text(RoutineDays.summary(routine.days))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(HubTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if pending.isEmpty, !(routine.steps ?? []).isEmpty {
                    HStack(spacing: 8) {
                        Text("All done for today!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                        if let days = viewModel.streak(for: routine.profileId)?.current,
                           days >= StreakHelpers.minimumToShow {
                            StreakChip(days: days)
                        }
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HubTheme.tileQuiet)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ForEach(pending) { step in
                        RoutineStepCheckRow(step: step, color: profile?.color) {
                            await viewModel.toggleStep(step.id)
                        } onFinished: {
                            viewModel.markStepCompleted(step.id)
                        }
                    }
                }

                let doneToday = viewModel.completedSteps(for: routine)
                if !doneToday.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DONE TODAY")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        ForEach(doneToday, id: \.step.id) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(HubTheme.sage)
                                Text(RoutineGlyphs.display(for: item.step.label).label)
                                    .font(.caption.weight(.bold))
                                if let caption = item.caption {
                                    Text(caption)
                                        .font(.caption)
                                        .foregroundStyle(HubTheme.muted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.canManage {
                    Button(action: onEdit) {
                        Label("Edit Routine", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                }
            }
        }
        .contextMenu {
            if viewModel.canManage {
                Button(action: onEdit) {
                    Label("Edit Routine", systemImage: "pencil")
                }
            }
        }
    }
}

private enum RoutineEditorPresentation: Identifiable {
    case add(UUID)
    case edit(String)

    var id: String {
        switch self {
        case .add(let id):
            "add-\(id.uuidString)"
        case .edit(let routineId):
            "edit-\(routineId)"
        }
    }
}

private struct RoutineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: RoutineEditorPresentation
    let routines: [Routine]
    let profiles: [Profile]
    @ObservedObject var viewModel: RoutinesViewModel

    private var routine: Routine? {
        guard case .edit(let routineId) = editor else { return nil }
        return routines.first { $0.id == routineId }
    }

    private var title: String {
        switch editor {
        case .add:
            "Add Routine"
        case .edit:
            "Edit Routine"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch editor {
                    case .add:
                        RoutineFormView(
                            profiles: profiles,
                            weekStartsOn: viewModel.weekStartsOn,
                            submitLabel: "Add Routine"
                        ) { input in
                            let saved = await viewModel.createRoutine(input)
                            if saved {
                                dismiss()
                            }
                            return saved
                        }
                    case .edit:
                        if let routine {
                            RoutineFormView(
                                profiles: profiles,
                                routine: routine,
                                weekStartsOn: viewModel.weekStartsOn,
                                submitLabel: "Save Routine",
                                onSubmit: { input in
                                    let saved = await viewModel.updateRoutine(id: routine.id, input: input)
                                    if saved {
                                        dismiss()
                                    }
                                    return saved
                                }
                            )
                        } else {
                            ContentUnavailableView(
                                "Routine Missing",
                                systemImage: "list.bullet.clipboard",
                                description: Text("This routine could not be found.")
                            )
                        }
                    }
                }
                .padding()
                // Room to scroll past the delete button pinned over the corner.
                .padding(.bottom, routine == nil ? 0 : 72)
            }
            .background(HubTheme.canvas)
            .cornerDeleteButton(
                isShown: routine != nil,
                accessibilityLabel: "Delete routine",
                confirmTitle: "Delete \(routine?.name ?? "this routine")?",
                confirmButton: "Delete Routine",
                message: "This removes the routine, its steps and their history."
            ) {
                guard let routine else { return }
                if await viewModel.deleteRoutine(id: routine.id) {
                    dismiss()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RoutineStepCheckRow: View {
    let step: RoutineStep
    var color: String?
    let onToggle: () async -> Bool
    let onFinished: () -> Void

    @State private var isHidden = false
    @State private var isCelebrating = false
    @State private var isWorking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Glyph and its tile scale together, or the emoji clips its container at
    // larger text sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 46
    @ScaledMetric(relativeTo: .largeTitle) private var glyphTileSize: CGFloat = 76
    @ScaledMetric(relativeTo: .title) private var stepLabelSize: CGFloat = 24

    private var display: RoutineStepDisplay {
        RoutineGlyphs.display(for: step.label)
    }

    private var tint: Color {
        HubTheme.profileColor(color)
    }

    var body: some View {
        if !isHidden {
            Button {
                Task {
                    guard !isWorking else { return }
                    isWorking = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.56)) {
                        isCelebrating = true
                    }
                    let succeeded = await onToggle()
                    guard succeeded else {
                        withAnimation {
                            isCelebrating = false
                        }
                        isWorking = false
                        return
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    let delay = reduceMotion ? 180_000_000 : 900_000_000
                    try? await Task.sleep(nanoseconds: UInt64(delay))
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isHidden = true
                    }
                    onFinished()
                }
            } label: {
                ZStack {
                    HStack(spacing: 16) {
                        Text(display.glyph)
                            .font(.system(size: glyphSize))
                            .frame(width: glyphTileSize, height: glyphTileSize)
                            .background(tint.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .scaleEffect(isCelebrating && !reduceMotion ? 1.12 : 1)
                            .rotationEffect(.degrees(isCelebrating && !reduceMotion ? -6 : 0))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(display.label)
                                .font(.system(size: stepLabelSize, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)

                            Label(
                                isCelebrating ? "Great job!" : "Tap when done",
                                systemImage: isCelebrating ? "checkmark.circle.fill" : "hand.tap.fill"
                            )
                            .font(.caption.weight(.heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(isCelebrating ? .white : tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isCelebrating ? tint : tint.opacity(0.14))
                            .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                    .background(tint.opacity(isCelebrating ? 0.22 : 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(tint.opacity(isCelebrating ? 0.78 : 0.28), lineWidth: 2)
                    )
                    .overlay {
                        if isCelebrating && !reduceMotion {
                            RoutineCelebrationBurst(tint: tint)
                        }
                    }
                }
                .shadow(color: tint.opacity(isCelebrating && !reduceMotion ? 0.22 : 0), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }
}
