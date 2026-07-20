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
    @State private var stepsText = ""
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
                TextField("One step per line", text: $stepsText, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Put each checklist item on a new line.")
                .font(.caption2)
                .foregroundStyle(HubTheme.muted)

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    let steps = stepsText
                        .split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
        stepsText = (routine.steps ?? []).map(\.label).joined(separator: "\n")
    }

    private func periodLabel(_ period: RoutinePeriod) -> String {
        switch period {
        case .morning: "Morning"
        case .afternoon: "After school"
        case .evening: "Bedtime"
        }
    }
}
