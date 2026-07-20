import SwiftUI

struct ChoreFormView: View {
    let profiles: [Profile]
    var chore: ChoreRow?
    let submitLabel: String
    var onSubmit: (ChoreInput) async -> Bool
    var onDelete: (() async -> Bool)?

    @State private var title = ""
    @State private var profileId: String?
    @State private var cadence: ChoreCadence = .daily
    @State private var weekDay = "1"
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Chore") {
                TextField("Feed the dog", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            FormField(label: "Assign to") {
                ProfilePickerField(profiles: profiles, profileId: $profileId)
            }

            FormField(label: "Frequency") {
                Picker("Cadence", selection: $cadence) {
                    Text("Every day").tag(ChoreCadence.daily)
                    Text("Once a week").tag(ChoreCadence.weekly)
                }
                .pickerStyle(.menu)
            }

            if cadence == .weekly {
                FormField(label: "Day of the week") {
                    Picker("Weekday", selection: $weekDay) {
                        ForEach(ChoreHelpers.weekdayOptions) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    let input = ChoreInput(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        profileId: profileId,
                        cadence: cadence,
                        weekDay: cadence == .weekly ? weekDay : nil
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let onDelete {
                Button("Delete chore", role: .destructive) {
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
        guard let chore else { return }
        title = chore.title
        profileId = chore.profileId
        cadence = chore.cadence
        weekDay = ChoreHelpers.weeklyChoreDay(chore.days)
    }
}
