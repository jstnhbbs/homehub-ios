import SwiftUI

struct ChoreFormView: View {
    let profiles: [Profile]
    var chore: ChoreRow?
    let timezone: TimeZone
    let submitLabel: String
    var onSubmit: (ChoreInput) async -> Bool
    var onDelete: (() async -> Bool)?

    @State private var title = ""
    @State private var profileId: String?
    @State private var cadence: ChoreCadence = .daily
    @State private var weekDay = "1"
    @State private var hasDueDate = false
    @State private var dueDate = Date()
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

            FormField(label: "Due date") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Has a due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
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
                        weekDay: cadence == .weekly ? weekDay : nil,
                        dueDate: hasDueDate ? DateHelpers.localDateIn(timezone: timezone, date: dueDate) : nil
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
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
        if let storedDueDate = chore.dueDate,
           let parsed = DateHelpers.dateFromLocalDate(storedDueDate, timezone: timezone) {
            hasDueDate = true
            dueDate = parsed
        }
    }
}
