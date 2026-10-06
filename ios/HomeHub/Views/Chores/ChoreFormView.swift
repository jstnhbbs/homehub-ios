import SwiftUI

struct ChoreFormView: View {
    let profiles: [Profile]
    var chore: ChoreRow?
    let timezone: TimeZone
    let submitLabel: String
    var onSubmit: (ChoreInput) async -> Bool

    @State private var title = ""
    @State private var profileId: String?
    @State private var preset: ChoreRepeatPreset = .daily
    @State private var customInterval = 2
    @State private var customUnit: ChoreRepeatUnit = .week
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasDueTime = false
    @State private var dueTime = ChoreFormView.defaultTime
    @State private var isSaving = false

    private static var defaultTime: Date {
        Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
    }

    private var rule: ChoreRepeatRule {
        preset == .custom ? ChoreRepeatRule(unit: customUnit, interval: customInterval) : (preset.rule ?? .daily)
    }

    /// Children, owners and parents. A chore already given to someone else stays on the list so
    /// editing it doesn't quietly hand it to "Everyone".
    private var assignableProfiles: [Profile] {
        profiles.filter { $0.canBeAssignedChores || $0.id == chore?.profileId }
    }

    /// A chore that counts from its date (every 2 weeks, monthly, …) always has one.
    private var requiresDate: Bool { ChoreHelpers.needsDate(rule) }
    private var datePresent: Bool { requiresDate || hasDueDate }
    private var offersTime: Bool { rule.unit != .never || datePresent }

    /// The sentence under the menu, when it says more than the menu item already does (the
    /// weekday, the day of the month, a custom interval).
    private var showsRuleSummary: Bool {
        switch preset {
        case .never, .daily, .weekdays: false
        default: true
        }
    }

    private var dueDateString: String? {
        datePresent ? DateHelpers.localDateIn(timezone: timezone, date: dueDate) : nil
    }

    private var dueTimeString: String? {
        guard offersTime, hasDueTime else { return nil }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// The weekday of the chosen date, as the server stores it (0 is Sunday).
    private var weekDayOfDate: String {
        String(DateHelpers.gregorian(in: timezone).component(.weekday, from: dueDate) - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Chore") {
                TextField("Feed the dog", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            FormField(label: "Assign to") {
                ProfilePickerField(profiles: assignableProfiles, profileId: $profileId)
            }

            repeatField
            dateField
            if offersTime {
                timeField
            }

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    _ = await onSubmit(ChoreHelpers.input(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        profileId: profileId,
                        rule: rule,
                        dueDate: dueDateString,
                        dueTime: dueTimeString,
                        weekDay: weekDayOfDate
                    ))
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        }
        .onAppear(perform: populate)
    }

    private var repeatField: some View {
        FormField(label: "Repeat") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Repeat", selection: $preset.animation()) {
                    ForEach(ChoreRepeatPreset.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if preset == .custom {
                    HStack {
                        Stepper("Every \(customInterval)", value: $customInterval, in: 1...99)
                        Picker("Unit", selection: $customUnit) {
                            Text(customInterval == 1 ? "Day" : "Days").tag(ChoreRepeatUnit.day)
                            Text(customInterval == 1 ? "Week" : "Weeks").tag(ChoreRepeatUnit.week)
                            Text(customInterval == 1 ? "Month" : "Months").tag(ChoreRepeatUnit.month)
                            Text(customInterval == 1 ? "Year" : "Years").tag(ChoreRepeatUnit.year)
                        }
                        .pickerStyle(.menu)
                    }
                }

                if showsRuleSummary {
                    Text(ChoreHelpers.repeatDetail(rule: rule, days: weekDayOfDate, dueDate: dueDateString, timezone: timezone))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
        }
    }

    private var dateField: some View {
        FormField(label: rule.unit == .never ? "Due date" : "Starts") {
            VStack(alignment: .leading, spacing: 8) {
                if requiresDate {
                    DatePicker("Starts", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                } else {
                    Toggle(rule.unit == .never ? "Has a due date" : "Has a start date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var timeField: some View {
        FormField(label: "Time") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(rule.unit == .never ? "Due at a time" : "Set a time", isOn: $hasDueTime.animation())
                if hasDueTime {
                    DatePicker("Time", selection: $dueTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }
        }
    }

    private func populate() {
        guard let chore else { return }
        title = chore.title
        profileId = chore.profileId
        let stored = ChoreHelpers.repeatRule(for: chore)
        preset = ChoreRepeatPreset.matching(stored)
        if preset == .custom {
            customUnit = stored.unit
            customInterval = stored.interval
        }
        if let storedDueDate = chore.dueDate,
           let parsed = DateHelpers.dateFromLocalDate(storedDueDate, timezone: timezone) {
            hasDueDate = true
            dueDate = parsed
        } else if stored.unit == .week {
            // A weekly chore made before dates counted for it: start it on its next day.
            let calendar = DateHelpers.gregorian(in: timezone)
            let wanted = Int(ChoreHelpers.weeklyChoreDay(chore.days)) ?? 1
            dueDate = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: .now) }
                .first { calendar.component(.weekday, from: $0) - 1 == wanted } ?? .now
        }
        if let storedTime = chore.dueTime,
           let (hour, minute) = ChoreHelpers.hourAndMinute(storedTime),
           let parsed = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) {
            hasDueTime = true
            dueTime = parsed
        }
    }
}
