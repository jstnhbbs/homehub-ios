import SwiftUI

struct RoutineFormView: View {
    let profiles: [Profile]
    var routine: Routine?
    /// The household's first day of the week, for the order of the day chips.
    var weekStartsOn = WeekStart.defaultWeekStartsOn
    let submitLabel: String
    var onSubmit: (RoutineInput) async -> Bool

    @State private var name = ""
    @State private var profileId: String?
    @State private var period: RoutinePeriod = .morning
    @State private var days: Set<Int> = RoutineDays.everyDay
    @State private var stepDrafts = [RoutineStepDraft()]
    @State private var isSaving = false
    @State private var dropTarget: UUID?
    @FocusState private var focusedStep: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Routine name") {
                TextField("Bedtime routine", text: $name)
                    .textFieldStyle(HubFieldStyle())
            }

            FormField(label: "Assign to") {
                ProfilePickerField(profiles: profiles, profileId: $profileId)
            }

            FormField(label: "Time of day") {
                Picker("Period", selection: $period) {
                    ForEach(RoutinePeriod.allCases, id: \.self) { value in
                        Text(periodLabel(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
            }

            FormField(label: "Days") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(RoutineDays.ordered(weekStartsOn: weekStartsOn), id: \.self) { weekday in
                            DayChip(weekday: weekday, isOn: days.contains(weekday)) {
                                toggle(weekday)
                            }
                        }
                    }
                    Text(days.isEmpty ? "Pick at least one day." : RoutineDays.summary(days))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(days.isEmpty ? Color.red : HubTheme.muted)
                }
            }

            FormField(label: "Steps") {
                VStack(spacing: 8) {
                    ForEach($stepDrafts) { $draft in
                        RoutineStepDraftRow(
                            draft: $draft,
                            focus: $focusedStep,
                            isDropTarget: dropTarget == draft.id,
                            onSubmit: { advance(from: draft.id) },
                            onDelete: { remove(draft.id) }
                        )
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let moving = UUID(uuidString: raw) else { return false }
                            move(moving, onto: draft.id)
                            return true
                        } isTargeted: { targeted in
                            if targeted {
                                dropTarget = draft.id
                            } else if dropTarget == draft.id {
                                dropTarget = nil
                            }
                        }
                        .accessibilityAction(named: "Move up") { shift(draft.id, by: -1) }
                        .accessibilityAction(named: "Move down") { shift(draft.id, by: 1) }
                    }

                    Button {
                        addStep()
                    } label: {
                        Label("Add step", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                }
            }

            Text("Choose a picture for each step so kids can spot their tasks quickly. Press and hold the handle on the left of a step, then drag to put the steps in order.")
                .font(.caption2)
                .foregroundStyle(HubTheme.muted)

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    let steps = stepDrafts
                        .map { RoutineGlyphs.storageValue(glyph: $0.glyph, label: $0.label) }
                        .filter { !$0.isEmpty }
                    guard !steps.isEmpty, !days.isEmpty else { return }
                    let input = RoutineInput(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        period: period,
                        profileId: profileId,
                        days: RoutineDays.storage(days),
                        steps: steps
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validStepDrafts.isEmpty || days.isEmpty)
        }
        .onAppear(perform: populate)
    }

    // MARK: Days

    private func toggle(_ weekday: Int) {
        if days.contains(weekday) {
            days.remove(weekday)
        } else {
            days.insert(weekday)
        }
    }

    // MARK: Steps

    private func addStep() {
        let draft = RoutineStepDraft()
        withAnimation { stepDrafts.append(draft) }
        focusedStep = draft.id
    }

    private func remove(_ id: UUID) {
        withAnimation {
            stepDrafts.removeAll { $0.id == id }
            if stepDrafts.isEmpty {
                stepDrafts.append(RoutineStepDraft())
            }
        }
    }

    /// Return in a step's field: on to the next step, or a new one after the last. An empty last
    /// step just closes the keyboard, so Return twice finishes the list.
    private func advance(from id: UUID) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < stepDrafts.count {
            focusedStep = stepDrafts[index + 1].id
        } else if stepDrafts[index].label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            focusedStep = nil
        } else {
            addStep()
        }
    }

    /// Drops `moving` where `target` is: after it when moving down the list, before it when up.
    private func move(_ moving: UUID, onto target: UUID) {
        guard moving != target,
              let from = stepDrafts.firstIndex(where: { $0.id == moving }),
              let to = stepDrafts.firstIndex(where: { $0.id == target }) else { return }
        withAnimation {
            stepDrafts.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        dropTarget = nil
    }

    private func shift(_ id: UUID, by offset: Int) {
        guard let from = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard stepDrafts.indices.contains(to) else { return }
        move(id, onto: stepDrafts[to].id)
    }

    private func populate() {
        guard let routine else { return }
        name = routine.name
        profileId = routine.profileId
        period = routine.period
        days = RoutineDays.parse(routine.days)
        stepDrafts = (routine.steps ?? [])
            .map { step in
                let display = RoutineGlyphs.display(for: step.label)
                return RoutineStepDraft(glyph: display.glyph, label: display.label)
            }
        if stepDrafts.isEmpty {
            stepDrafts = [RoutineStepDraft()]
        }
    }

    private var validStepDrafts: [RoutineStepDraft] {
        stepDrafts.filter { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func periodLabel(_ period: RoutinePeriod) -> String {
        switch period {
        case .morning: "Morning"
        case .afternoon: "After school"
        case .evening: "Bedtime"
        }
    }
}

private struct RoutineStepDraft: Identifiable, Equatable {
    let id = UUID()
    var glyph: String = RoutineGlyphs.fallbackGlyph
    var label: String = ""
}

private struct DayChip: View {
    let weekday: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(RoutineDays.shortName(weekday))
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(isOn ? HubTheme.onAccent : Color.primary)
                .background(isOn ? HubTheme.sage : HubTheme.tileQuiet)
                .clipShape(Circle())
                .overlay(Circle().stroke(isOn ? Color.clear : HubTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(RoutineDays.fullName(weekday))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

private struct RoutineStepDraftRow: View {
    @Binding var draft: RoutineStepDraft
    var focus: FocusState<UUID?>.Binding
    let isDropTarget: Bool
    let onSubmit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Press and hold, then drag, to move the step. Only the handle lifts, so the text
            // field and the picture menu keep their own taps.
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .frame(width: 28, height: 44)
                .contentShape(Rectangle())
                .draggable(draft.id.uuidString) {
                    Text("\(draft.glyph) \(draft.label)")
                        .padding(10)
                        .background(HubTheme.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityHidden(true)

            Menu {
                ForEach(RoutineGlyphs.options) { option in
                    Button {
                        draft.glyph = option.glyph
                        if draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.label = option.label
                        }
                    } label: {
                        Text("\(option.glyph) \(option.label)")
                    }
                }
            } label: {
                Text(draft.glyph)
                    .font(.title2)
                    .frame(width: 48, height: 44)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            TextField("Brush teeth", text: $draft.label)
                .textFieldStyle(HubFieldStyle())
                .focused(focus, equals: draft.id)
                .submitLabel(.next)
                .onSubmit(onSubmit)
                .onChange(of: draft.label) { oldValue, newValue in
                    let oldInferred = RoutineGlyphs.display(for: oldValue).glyph
                    if draft.glyph == oldInferred || draft.glyph == RoutineGlyphs.fallbackGlyph {
                        draft.glyph = RoutineGlyphs.display(for: newValue).glyph
                    }
                }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HubTheme.coral)
                    // A full-size touch target: the icon alone is about 22pt.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove step")
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTarget ? HubTheme.sage.opacity(0.14) : Color.clear)
        )
    }
}
