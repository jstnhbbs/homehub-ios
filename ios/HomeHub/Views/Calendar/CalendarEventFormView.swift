import SwiftUI

struct CalendarEventFormView: View {
    let calendars: [CalendarPickerOption]
    let timezone: TimeZone
    let submitLabel: String
    var event: CalendarOccurrence?
    var defaultSelectedDate: String

    var onSubmit: (CalendarEventFormInput) async -> Bool
    var onDelete: (() async -> Bool)?

    @State private var title = ""
    @State private var calendarId = ""
    @State private var allDay = false
    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(3600)
    @State private var location = ""
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Title") {
                TextField("Event title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            if !calendars.isEmpty {
                labeledField("Calendar") {
                    Picker("Calendar", selection: $calendarId) {
                        ForEach(calendars) { calendar in
                            Text(calendarLabel(calendar)).tag(calendar.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Toggle("All-day event", isOn: $allDay)
                .font(.caption.weight(.bold))
                .onChange(of: allDay) { _, isAllDay in
                    normalizeDatesForAllDay(isAllDay)
                }

            labeledField("Starts") {
                if allDay {
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                } else {
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
            }

            labeledField("Ends") {
                if allDay {
                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                } else {
                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
            }

            labeledField("Location") {
                TextField("Optional", text: $location)
                    .textFieldStyle(.roundedBorder)
            }

            labeledField("Notes") {
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
            }

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
                    let input = CalendarEventFormInput(
                        calendarId: calendarId,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        startsAt: CalendarHelpers.formatFormDate(startDate, allDay: allDay, timezone: timezone),
                        endsAt: CalendarHelpers.formatFormDate(endDate, allDay: allDay, timezone: timezone),
                        allDay: allDay,
                        location: location.isEmpty ? nil : location,
                        description: notes.isEmpty ? nil : notes
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calendarId.isEmpty)

            if let onDelete {
                Button("Delete event", role: .destructive) {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        _ = await onDelete()
                    }
                }
                .disabled(isSaving)
            }

            Text("Times use your household timezone (\(timezone.identifier.replacingOccurrences(of: "_", with: " "))).")
                .font(.caption2)
                .foregroundStyle(HubTheme.muted)
        }
        .onAppear(perform: populateDefaults)
    }

    private func populateDefaults() {
        if let event {
            title = event.title
            calendarId = event.calendarId ?? calendars.first?.id ?? ""
            allDay = event.allDay
            let fields = CalendarHelpers.fieldValues(for: event, timezone: timezone)
            startDate = CalendarHelpers.parseFormDate(fields.startsAt, timezone: timezone) ?? .now
            endDate = CalendarHelpers.parseFormDate(fields.endsAt, timezone: timezone) ?? startDate.addingTimeInterval(3600)
            location = event.location ?? ""
            notes = event.description ?? ""
        } else {
            calendarId = calendars.first?.id ?? ""
            let fields = CalendarHelpers.defaultTimedFields(selectedDate: defaultSelectedDate, timezone: timezone)
            startDate = CalendarHelpers.parseFormDate(fields.startsAt, timezone: timezone) ?? .now
            endDate = CalendarHelpers.parseFormDate(fields.endsAt, timezone: timezone) ?? startDate.addingTimeInterval(3600)
        }
    }

    private func normalizeDatesForAllDay(_ isAllDay: Bool) {
        if isAllDay {
            endDate = max(endDate, startDate)
        } else if endDate < startDate {
            endDate = startDate.addingTimeInterval(3600)
        }
    }

    private func calendarLabel(_ calendar: CalendarPickerOption) -> String {
        let providers = Set(calendars.map(\.provider))
        if providers.count > 1 {
            return "\(calendar.displayName) · \(calendar.provider.rawValue.capitalized)"
        }
        return calendar.displayName
    }

    @ViewBuilder
    private func labeledField<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
            content()
        }
    }
}
