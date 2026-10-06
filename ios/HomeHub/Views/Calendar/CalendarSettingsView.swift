import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CalendarSettingsViewModel()
    @AppStorage(NativeCalendarPreferenceKeys.defaultNewItem) private var defaultNewItem = NativeNewItemKind.event.rawValue
    @AppStorage(NativeCalendarPreferenceKeys.eventAlert) private var eventAlertMinutes = NativeAlertOffset.fifteenMinutes.rawValue
    @AppStorage(NativeCalendarPreferenceKeys.reminderAlert) private var reminderAlertMinutes = NativeAlertOffset.atTime.rawValue
    @AppStorage(NativeCalendarPreferenceKeys.agendaFontSize) private var agendaFontSize = 15.0
    @AppStorage(NativeCalendarPreferenceKeys.useSystemAgendaFont) private var useSystemAgendaFont = true

    private let agendaFontRange = 11.0...24.0

    var body: some View {
        Form {
            statusSection
            accessSection
            defaultsSection
            agendaFontSection
            if viewModel.hasCalendarAccess {
                calendarSelection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isLoading {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        if let error = viewModel.errorMessage {
            Section {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        if let success = viewModel.successMessage {
            Section {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(HubTheme.sage)
            }
        }
    }

    private var accessSection: some View {
        Section {
            accessRow(
                title: "Calendar",
                systemImage: "calendar",
                status: viewModel.nativeAccessStatus.settingsLabel,
                isAuthorized: viewModel.hasCalendarAccess,
                needsPermission: viewModel.needsCalendarPermission,
                isDenied: viewModel.calendarAccessDenied
            ) {
                Task { await viewModel.requestNativeCalendarAccess() }
            }

            accessRow(
                title: "Reminders",
                systemImage: "checklist",
                status: viewModel.remindersAccessStatus.settingsLabel,
                isAuthorized: viewModel.hasRemindersAccess,
                needsPermission: viewModel.needsRemindersPermission,
                isDenied: viewModel.remindersAccessDenied
            ) {
                Task { await viewModel.requestNativeRemindersAccess() }
            }
        } header: {
            Text("Calendar and Reminders")
        } footer: {
            Text("Beacon reads Apple Calendar on this device and can write grocery items to Reminders.")
        }
    }

    private func accessRow(
        title: String,
        systemImage: String,
        status: String,
        isAuthorized: Bool,
        needsPermission: Bool,
        isDenied: Bool,
        request: @escaping () -> Void
    ) -> some View {
        Button {
            if needsPermission {
                request()
            } else {
                viewModel.openSystemSettings()
            }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                if isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text(status)
                        .foregroundStyle(.secondary)
                } else {
                    Text(status)
                        .foregroundStyle(isDenied ? Color.red : Color.accentColor)
                }
            }
        }
        .disabled(viewModel.isWorking)
    }

    private var defaultsSection: some View {
        Section {
            Picker("Default New Item Creation", selection: $defaultNewItem) {
                ForEach(NativeNewItemKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }

            Picker("Default Calendar", selection: $viewModel.defaultCalendarId) {
                Text("Automatic").tag(NativeCalendarPreferenceKeys.automaticId)
                ForEach(viewModel.writableCalendars) { calendar in
                    Text(calendar.displayName).tag(calendar.id)
                }
            }
            .disabled(!viewModel.hasCalendarAccess)
            .onChange(of: viewModel.defaultCalendarId) { _, _ in
                viewModel.saveDefaultCalendar()
            }

            Picker("Default Reminders List", selection: $viewModel.defaultReminderListId) {
                Text("Automatic").tag(NativeCalendarPreferenceKeys.automaticId)
                ForEach(viewModel.reminderLists) { list in
                    Text(list.title).tag(list.id)
                }
            }
            .disabled(!viewModel.hasRemindersAccess || !viewModel.canManageReminderList)
            .onChange(of: viewModel.defaultReminderListId) { _, _ in
                viewModel.saveDefaultReminderList()
            }

            Picker("Default Event Alert", selection: $eventAlertMinutes) {
                ForEach(NativeAlertOffset.allCases) { offset in
                    Text(offset.label).tag(offset.rawValue)
                }
            }

            Picker("Default Reminder Alert", selection: $reminderAlertMinutes) {
                ForEach(NativeAlertOffset.allCases) { offset in
                    Text(offset.label).tag(offset.rawValue)
                }
            }
        } footer: {
            Text(viewModel.canManageReminderList
                ? "Automatic uses this device’s default Calendar and Reminders destinations. Alerts apply to new items created in Beacon."
                : "Owners and parents can choose the Reminders list used for groceries. Alerts apply to new items created in Beacon.")
        }
    }

    private var agendaFontSection: some View {
        Section {
            HStack {
                Text("Event Font Size")
                Spacer()
                Text("\(Int(agendaFontSize.rounded())) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button {
                    agendaFontSize = max(agendaFontRange.lowerBound, agendaFontSize - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .disabled(useSystemAgendaFont || agendaFontSize <= agendaFontRange.lowerBound)

                Button {
                    agendaFontSize = min(agendaFontRange.upperBound, agendaFontSize + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .disabled(useSystemAgendaFont || agendaFontSize >= agendaFontRange.upperBound)
            }

            Toggle("Use System Size", isOn: $useSystemAgendaFont)
        } footer: {
            Text("Controls event text in Day view. System size follows Dynamic Type.")
        }
    }

    @ViewBuilder
    private var calendarSelection: some View {
        if viewModel.calendars.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Calendars",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No calendars are available on this device.")
                )
            } header: {
                Text("Calendars Shown in Beacon")
            }
        } else {
            ForEach(CalendarPickerOption.groupedByAccount(viewModel.calendars), id: \.account) { group in
                Section {
                    ForEach(group.calendars) { calendar in
                        calendarToggle(calendar)
                    }
                } header: {
                    Text(group.account)
                }
            }

            Section {
                Button {
                    viewModel.selectAllCalendars()
                } label: {
                    Label("Select All", systemImage: "checklist.checked")
                }
                .disabled(viewModel.isWorking || allCalendarsSelected)
            } footer: {
                if viewModel.selectedCalendarIds.isEmpty {
                    Text("No calendars are on, so Beacon shows no events. Changes apply as soon as you make them.")
                } else {
                    Text("Changes apply as soon as you make them. Calendars that are off stay hidden in Beacon.")
                }
            }
        }
    }

    private var allCalendarsSelected: Bool {
        Set(viewModel.calendars.map(\.id)).isSubset(of: viewModel.selectedCalendarIds)
    }

    private func calendarToggle(_ calendar: CalendarPickerOption) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.selectedCalendarIds.contains(calendar.id) },
            set: { enabled in
                viewModel.setCalendar(calendar.id, enabled: enabled)
            }
        )) {
            Label {
                Text(calendar.displayName)
            } icon: {
                Circle()
                    .fill(HubTheme.profileColor(calendar.color))
                    .frame(width: 12, height: 12)
            }
        }
    }
}
