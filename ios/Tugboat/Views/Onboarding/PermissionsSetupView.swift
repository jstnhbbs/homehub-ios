import SwiftUI

/// Shown once after signing in, when something the app can use has not been asked about yet: it says what each
/// permission is for and lets the person allow it now or move on. Nothing is requested until a button is tapped, so
/// iOS never interrupts someone who has not been told why. Everything here can still be changed later in
/// Settings → Privacy & Access.
struct PermissionsSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    let onFinish: () -> Void

    /// The UserDefaults key that remembers this screen has been dealt with.
    static let seenKey = "tugboat.permissionsSetupSeen"

    private enum Kind: CaseIterable, Identifiable {
        case calendar, reminders, location, notifications
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Get Set Up")
                            .font(HubTheme.pageTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("Tugboat works best with a few things on your device. Allow what you'd like now; you can change any of it later in Settings.")
                            .font(.body)
                            .foregroundStyle(HubTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(visibleKinds.enumerated()), id: \.element) { index, kind in
                            if index > 0 { Divider().overlay(HubTheme.line) }
                            row(kind)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .hubGlass(cornerRadius: 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }

            Button {
                onFinish()
            } label: {
                Text(anyAllowed ? "Continue" : "Not Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubTheme.canvas.ignoresSafeArea())
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
    }

    // MARK: Rows

    private var visibleKinds: [Kind] {
        Kind.allCases.filter { state(of: $0) != .unavailable }
    }

    private var anyAllowed: Bool {
        Kind.allCases.contains { state(of: $0) == .allowed }
    }

    private func row(_ kind: Kind) -> some View {
        let state = state(of: kind)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon(kind))
                .font(.headline.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)
                .frame(width: 38, height: 38)
                .background(HubTheme.sageSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title(kind))
                    .font(.body.weight(.semibold))
                Text(detail(kind))
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            switch state {
            case .allowed:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.accentText)
            case .notAsked:
                Button("Allow") { Task { await request(kind) } }
                    .buttonStyle(HubButtonStyle(emphasis: .primary, size: .small))
                    .accessibilityLabel("Allow \(title(kind))")
            case .denied:
                Button("Settings") { openSystemSettings() }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                    .accessibilityLabel("Open Settings for \(title(kind))")
            case .unavailable:
                EmptyView()
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

    // MARK: State and actions

    private enum RowState: Equatable { case allowed, notAsked, denied, unavailable }

    private func state(of kind: Kind) -> RowState {
        switch kind {
        case .calendar:
            switch appState.nativeCalendar.accessStatus {
            case .authorized: .allowed
            case .notDetermined: .notAsked
            case .denied, .restricted: .denied
            }
        case .reminders:
            switch appState.nativeReminders.accessStatus {
            case .authorized: .allowed
            case .notDetermined: .notAsked
            case .denied, .restricted: .denied
            }
        case .location:
            switch appState.nativeWeather.accessStatus {
            case .authorized: .allowed
            case .notDetermined: .notAsked
            case .denied, .restricted: .denied
            case .unavailable: .unavailable
            }
        case .notifications:
            switch appState.nativeNotifications.accessStatus {
            case .authorized, .provisional, .ephemeral: .allowed
            case .notDetermined: .notAsked
            case .denied: .denied
            }
        }
    }

    private func request(_ kind: Kind) async {
        switch kind {
        case .calendar:
            await appState.nativeCalendar.requestFullAccess()
            await appState.refreshNativeTodaySchedule()
        case .reminders:
            await appState.nativeReminders.requestFullAccess()
            await appState.refreshNativeGroceryItems()
        case .location:
            await appState.nativeWeather.requestAccessAndRefresh()
        case .notifications:
            await appState.nativeNotifications.requestAuthorization()
        }
    }

    private func refresh() async {
        appState.nativeCalendar.refreshAccessStatus()
        appState.nativeReminders.refreshAccessStatus()
        await appState.nativeNotifications.refreshAccessStatus()
        await appState.nativeWeather.activateIfAuthorized()
    }

    /// Whether anything is still unasked, which is the only reason to show this screen. Run once after sign-in.
    static func hasUnaskedPermission(in appState: AppState) async -> Bool {
        appState.nativeCalendar.refreshAccessStatus()
        appState.nativeReminders.refreshAccessStatus()
        await appState.nativeNotifications.refreshAccessStatus()
        await appState.nativeWeather.activateIfAuthorized()
        return appState.nativeCalendar.accessStatus == .notDetermined
            || appState.nativeReminders.accessStatus == .notDetermined
            || appState.nativeNotifications.accessStatus == .notDetermined
            || appState.nativeWeather.accessStatus == .notDetermined
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Words

    private func icon(_ kind: Kind) -> String {
        switch kind {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .location: "location.fill"
        case .notifications: "bell.badge"
        }
    }

    private func title(_ kind: Kind) -> String {
        switch kind {
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .location: "Location"
        case .notifications: "Notifications"
        }
    }

    private func detail(_ kind: Kind) -> String {
        switch kind {
        case .calendar: "Shows today's events from the calendars on this device. They stay on your device."
        case .reminders: "Lets groceries live in an Apple Reminders list you can share."
        case .location: "Your approximate location, only to show the local weather."
        case .notifications: "Routine, chore, bedtime and nap reminders, with buttons to finish them from the lock screen."
        }
    }
}
