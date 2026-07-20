import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CalendarSettingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let success = viewModel.successMessage {
                Text(success).font(.footnote).foregroundStyle(HubTheme.sage)
            }

            if viewModel.isLoading && viewModel.connections.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else {
                displaySettings
                autoSyncSettings
                syncButton
                providerSection(.icloud)
                providerSection(.google)
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Private, two-way sync")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(HubTheme.sage)
            Text("Calendars")
                .font(.title2.weight(.semibold))
            Text("Connect Apple or Google calendars for the family hub.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)
        }
    }

    private var displaySettings: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calendar display")
                    .font(.headline)
                Text("Choose which day starts the week on the calendar and meal plan.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                Picker("Start week on", selection: $viewModel.weekStartsOn) {
                    ForEach(WeekStart.options) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)

                Button("Save week start") {
                    Task { _ = await viewModel.saveWeekStart() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking)
            }
        }
    }

    private var autoSyncSettings: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Auto-sync")
                    .font(.headline)
                Text("How often Home Hub checks connected calendars while the app is open.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                Picker("Sync frequency", selection: $viewModel.syncIntervalMinutes) {
                    ForEach(CalendarSyncInterval.options) { option in
                        Text(option.label).tag(option.minutes)
                    }
                }
                .pickerStyle(.menu)

                Button("Save frequency") {
                    Task { _ = await viewModel.saveSyncInterval() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking)
            }
        }
    }

    private var syncButton: some View {
        HStack {
            if let label = appState.dashboard?.calendarStatus.updatedLabel {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
            Spacer()
            Button {
                Task { await viewModel.syncNow() }
            } label: {
                if viewModel.isWorking {
                    ProgressView()
                } else {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func providerSection(_ provider: CalendarProvider) -> some View {
        let connection = provider == .icloud ? viewModel.icloudConnection : viewModel.googleConnection
        let title = provider == .google ? "Google Calendar" : "Apple Calendar"

        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                if let connection {
                    connectedProviderHeader(title: title, connection: connection)
                    calendarSelection(provider: provider)
                    if connection.status == .error, let message = connection.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button("Disconnect \(title)", role: .destructive) {
                        Task { _ = await viewModel.disconnect(provider: provider) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isWorking)
                } else if provider == .google {
                    Text(title).font(.headline)
                    Text("Sign in with Google to sync calendars both ways. Home Hub stores an encrypted refresh token and only uses it for calendar access.")
                        .font(.footnote)
                        .foregroundStyle(HubTheme.muted)
                    Button("Connect Google Calendar") {
                        Task { _ = await viewModel.connectGoogle() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HubTheme.sage)
                    .disabled(viewModel.isWorking)
                } else {
                    appleConnectForm(title: title)
                }
            }
        }
    }

    private func connectedProviderHeader(title: String, connection: CalendarConnection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(title) connected", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(HubTheme.sage)
            Text(connection.accountEmail)
                .font(.subheadline)
                .foregroundStyle(HubTheme.muted)
            if let lastSynced = connection.lastSyncedAt {
                Text("Last synced \(lastSynced.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }

    @ViewBuilder
    private func calendarSelection(provider: CalendarProvider) -> some View {
        let items = viewModel.calendars(for: provider)
        if !items.isEmpty {
            Text("Calendars shown on the hub")
                .font(.subheadline.weight(.bold))
            Text("Enable calendars to display and sync events. Unselected calendars stay private.")
                .font(.caption)
                .foregroundStyle(HubTheme.muted)

            ForEach(items) { calendar in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedCalendarIds.contains(calendar.id) },
                    set: { enabled in
                        if enabled {
                            viewModel.selectedCalendarIds.insert(calendar.id)
                        } else {
                            viewModel.selectedCalendarIds.remove(calendar.id)
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(HubTheme.profileColor(calendar.color))
                            .frame(width: 12, height: 12)
                        Text(calendar.displayName)
                    }
                }
            }

            Button("Save calendar selection") {
                Task { _ = await viewModel.saveCalendarSelection() }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(viewModel.isWorking)
        }
    }

    private func appleConnectForm(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text("Create an app-specific password in your Apple Account security settings, then paste it here—not your Apple Account password.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)

            Link("Open Apple Account", destination: URL(string: "https://account.apple.com/account/manage")!)

            FormField(label: "Apple Account email") {
                TextField("you@icloud.com", text: $viewModel.appleEmail)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }

            FormField(label: "App-specific password") {
                SecureField("xxxx-xxxx-xxxx-xxxx", text: $viewModel.applePassword)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Connect Apple Calendar") {
                Task { _ = await viewModel.connectApple() }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(viewModel.isWorking)
        }
    }
}
