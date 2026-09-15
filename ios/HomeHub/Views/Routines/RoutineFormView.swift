import SwiftUI

struct RoutineFormView: View {
    let profiles: [Profile]
    var routine: Routine?
    let submitLabel: String
    var onSubmit: (RoutineInput) async -> Bool
    var onDelete: (() async -> Bool)?

    @State private var name = ""
    @State private var profileId: String?
    @State private var period: RoutinePeriod = .morning
    @State private var stepDrafts = [RoutineStepDraft()]
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Routine name") {
                TextField("Bedtime routine", text: $name)
                    .textFieldStyle(.roundedBorder)
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

            FormField(label: "Steps") {
                VStack(spacing: 8) {
                    ForEach($stepDrafts) { $draft in
                        RoutineStepDraftRow(draft: $draft) {
                            withAnimation {
                                stepDrafts.removeAll { $0.id == draft.id }
                                if stepDrafts.isEmpty {
                                    stepDrafts.append(RoutineStepDraft())
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation {
                            stepDrafts.append(RoutineStepDraft())
                        }
                    } label: {
                        Label("Add step", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                }
            }

            Text("Choose a picture for each step so kids can spot their tasks quickly.")
                .font(.caption2)
                .foregroundStyle(HubTheme.muted)

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    let steps = stepDrafts
                        .map { RoutineGlyphs.storageValue(glyph: $0.glyph, label: $0.label) }
                        .filter { !$0.isEmpty }
                    guard !steps.isEmpty else { return }
                    let input = RoutineInput(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        period: period,
                        profileId: profileId,
                        days: "0,1,2,3,4,5,6",
                        steps: steps
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validStepDrafts.isEmpty)

            if let onDelete {
                Button("Delete routine", role: .destructive) {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        _ = await onDelete()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let routine else { return }
        name = routine.name
        profileId = routine.profileId
        period = routine.period
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

private struct RoutineStepDraftRow: View {
    @Binding var draft: RoutineStepDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
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
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.label) { oldValue, newValue in
                    let oldInferred = RoutineGlyphs.display(for: oldValue).glyph
                    if draft.glyph == oldInferred || draft.glyph == RoutineGlyphs.fallbackGlyph {
                        draft.glyph = RoutineGlyphs.display(for: newValue).glyph
                    }
                }

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(HubTheme.coral)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove step")
        }
    }
}
