import SwiftUI
import UniformTypeIdentifiers

enum SettingsPresentation {
    case split
    case tabRoot
    case pushed
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    var presentation: SettingsPresentation = .split
    @StateObject private var viewModel = ProfilesViewModel()
    @StateObject private var membersViewModel = HouseholdMembersViewModel()
    @State private var activeProfileEditor: ProfileEditorPresentation?
    @State private var weekStartsOn = WeekStart.defaultWeekStartsOn
    @State private var isSavingWeekStart = false

    var body: some View {
        Group {
            if presentation == .split {
                NavigationStack {
                    settingsContent
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.large)
                }
            } else {
                settingsContent
                    .navigationTitle(presentation == .pushed ? "Settings" : "")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(presentation == .tabRoot ? .hidden : .automatic, for: .navigationBar)
            }
        }
        .sheet(item: $activeProfileEditor) { editor in
            ProfileEditorSheet(
                editor: editor,
                profiles: viewModel.profiles,
                timezone: viewModel.timezone,
                viewModel: viewModel
            )
            .environmentObject(appState)
        }
        .onAppear {
            viewModel.bind(to: appState)
            membersViewModel.bind(to: appState)
            applyPendingProfileEdit()
        }
        .onChange(of: appState.pendingProfileEditId) { _, _ in
            applyPendingProfileEdit()
        }
        .task {
            await viewModel.load()
            await membersViewModel.load()
            applyPendingProfileEdit()
        }
    }

    private var settingsContent: some View {
        settingsIndex
            .navigationDestination(for: SettingsTab.self) { tab in
                settingsPage(tab)
                    .navigationTitle(tab.label)
                    .navigationBarTitleDisplayMode(.inline)
            }
    }

    @ViewBuilder
    private var settingsIndex: some View {
        List {
            accountHeader
            statusMessagesSection

            Section {
                settingsRow(.general)
                settingsRow(.family)
            } header: {
                Text("Household")
            }

            Section {
                settingsRow(.calendar)
                settingsRow(.notifications)
                settingsRow(.layout)
            } header: {
                Text("Beacon")
            }

            Section {
                settingsRow(.data)
                settingsRow(.about)
            } header: {
                Text("Support")
            } footer: {
                Text("Web account setup stays minimal; day-to-day preferences live here in the iOS app.")
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await viewModel.load()
            await membersViewModel.load()
        }
    }

    private var accountHeader: some View {
        Section {
            HStack(spacing: 14) {
                ProfileAvatarView(
                    name: appState.currentUser?.name ?? "Beacon",
                    avatar: appState.currentUser?.image,
                    color: appState.myProfile(from: viewModel.profiles)?.color ?? "#4f7c6d",
                    size: 56
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.currentUser?.name ?? "Signed in")
                        .font(.headline)
                    Text(appState.currentUser?.email ?? appState.household?.name ?? "Beacon")
                        .font(.subheadline)
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let role = appState.household?.role {
                    Text(HouseholdRoles.roleLabel(role))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(HubTheme.sageSoft)
                        .foregroundStyle(HubTheme.sage)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func settingsRow(_ tab: SettingsTab) -> some View {
        NavigationLink(value: tab) {
            HStack(spacing: 14) {
                SettingsIconTile(tab: tab)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.label)
                        .font(.body)
                    Text(tab.description)
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let value = trailingValue(for: tab) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
        }
    }

    private func trailingValue(for tab: SettingsTab) -> String? {
        switch tab {
        case .general:
            appState.appearanceMode.label
        case .family:
            "\(viewModel.profiles.count)"
        case .calendar:
            if appState.nativeCalendar.hasFullAccess && appState.nativeReminders.hasFullAccess {
                "On"
            } else if appState.nativeCalendar.hasFullAccess || appState.nativeReminders.hasFullAccess {
                "Partial"
            } else {
                "Off"
            }
        case .notifications:
            switch appState.nativeNotifications.accessStatus {
            case .authorized, .provisional, .ephemeral:
                "On"
            case .denied:
                "Off"
            case .notDetermined:
                "Ask"
            }
        case .layout:
            "\(appState.hubModules.dashboardOrder.count)"
        case .data:
            appState.household == nil ? "Offline" : "Signed in"
        case .about:
            appVersionLabel
        }
    }

    @ViewBuilder
    private var statusMessagesSection: some View {
        if viewModel.errorMessage != nil ||
            viewModel.successMessage != nil ||
            membersViewModel.errorMessage != nil ||
            membersViewModel.successMessage != nil {
            Section {
                statusMessages
            }
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let error = viewModel.errorMessage {
            Text(error).font(.footnote).foregroundStyle(.red)
        }
        if let success = viewModel.successMessage {
            Text(success).font(.footnote).foregroundStyle(HubTheme.sage)
        }
        if let membersError = membersViewModel.errorMessage {
            Text(membersError).font(.footnote).foregroundStyle(.red)
        }
        if let membersSuccess = membersViewModel.successMessage {
            Text(membersSuccess).font(.footnote).foregroundStyle(HubTheme.sage)
        }
    }

    @ViewBuilder
    private func settingsPage(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalTab
        case .family:
            usersTab
        case .calendar:
            CalendarSettingsView()
        case .notifications:
            NativeNotificationsSettingView(service: appState.nativeNotifications)
        case .layout:
            ScrollView {
                HubModulesSettingView()
                    .padding()
            }
            .background(HubTheme.canvas)
        case .data:
            dataTab
        case .about:
            aboutTab
        }
    }

    private var generalTab: some View {
        Form {
            if let household = appState.household {
                householdSection(household)
            }

            if appState.household != nil {
                dateSection
            }
            ThemeSettingView()

            Section {
                Button("Sign Out", role: .destructive) {
                    Task { await appState.signOut() }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            if let household = appState.household {
                weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            }
        }
    }

    private var dateSection: some View {
        Section {
            Picker("Week Starts On", selection: $weekStartsOn) {
                ForEach(WeekStart.options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .disabled(isSavingWeekStart || !appState.canManageHousehold)
            .onChange(of: weekStartsOn) { _, value in
                Task { await saveWeekStart(value) }
            }
        } header: {
            Text("Date")
        } footer: {
            Text("Used by the calendar and meal plan.")
        }
    }

    private func saveWeekStart(_ value: Int) async {
        guard appState.canManageHousehold else { return }
        guard let current = appState.household?.weekStartsOn,
              WeekStart.parseWeekStartsOn(current) != value else { return }
        isSavingWeekStart = true
        defer { isSavingWeekStart = false }
        do {
            let household = try await appState.api.updateCalendarSettings(
                UpdateCalendarSettingsRequest(weekStartsOn: value)
            )
            appState.household = household
            await appState.refreshDashboard()
            weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
        } catch {
            if let household = appState.household {
                weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            }
        }
    }

    private var usersTab: some View {
        Form {
            if let household = appState.household {
                Section {
                    HouseholdPhotoUploadView(household: household)
                } header: {
                    Text("Family photo")
                } footer: {
                    Text("Shown in the top-left sidebar instead of the family-name letter.")
                }

                Section {
                    LabeledContent("Parent invite", value: household.inviteCode)
                    LabeledContent("Guest invite", value: household.guestInviteCode)
                } header: {
                    Text("Invite codes")
                } footer: {
                    Text("Share the parent code with another parent after they create an account. The guest code is for grandparents, nannies, and other helpers.")
                }
                .textSelection(.enabled)
            }

            if appState.canManageHousehold {
                membersSection
            }

            profilesSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var dataTab: some View {
        Form {
            Section {
                LabeledContent("Backend", value: AppConfig.baseURL.absoluteString)
                LabeledContent("Session", value: appState.currentUser == nil ? "Signed out" : "Signed in")
                LabeledContent("Local cache", value: appState.dashboard == nil ? "Empty" : "Ready")
            } header: {
                Text("Sync Status")
            } footer: {
                Text("Beacon stores household data on the backend and uses local device services for calendars, reminders, weather, and notifications.")
            }

            Section {
                Button {
                    Task {
                        await appState.refreshHousehold()
                        await appState.refreshDashboard()
                        await appState.refreshNativeTodaySchedule()
                    }
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var aboutTab: some View {
        Form {
            Section {
                LabeledContent("Version", value: appVersionLabel)
                LabeledContent("Calendar", value: "Native iOS")
                LabeledContent("Backend", value: "Beacon web API")
            } header: {
                Text("About Beacon")
            }

            Section {
                Link(destination: AppConfig.baseURL.appending(path: "privacy")) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                Link(destination: AppConfig.baseURL.appending(path: "terms")) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func applyPendingProfileEdit() {
        guard appState.selectedDestination == .settings,
              let profileId = appState.pendingProfileEditId else { return }
        viewModel.showAddForm = false
        viewModel.selectedProfileId = profileId
        activeProfileEditor = .edit(profileId)
        appState.pendingProfileEditId = nil
    }

    private func householdSection(_ household: Household) -> some View {
        Section("Household") {
            LabeledContent("Name", value: household.name)
            LabeledContent("Timezone", value: household.timezone)
            LabeledContent("Your role", value: HouseholdRoles.roleLabel(household.role))
        }
    }

    private var membersSection: some View {
        Section {
            if membersViewModel.isLoading && membersViewModel.members.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if membersViewModel.members.isEmpty {
                ContentUnavailableView(
                    "No Members",
                    systemImage: "person.2.slash",
                    description: Text("No household members were found.")
                )
            } else {
                ForEach(membersViewModel.members) { member in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.headline)
                            Text(member.email)
                                .font(.caption)
                                .foregroundStyle(HubTheme.muted)
                        }
                        Spacer()
                        memberRoleControl(member)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if member.role == .guest {
                            Button(role: .destructive) {
                                Task { await membersViewModel.removeGuest(userId: member.userId) }
                            } label: {
                                Label("Remove", systemImage: "person.crop.circle.badge.minus")
                            }
                            .disabled(membersViewModel.isWorking)
                        }
                    }
                    .contextMenu {
                        if member.role == .guest {
                            Button(role: .destructive) {
                                Task { await membersViewModel.removeGuest(userId: member.userId) }
                            } label: {
                                Label("Remove Guest", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Household Members")
        } footer: {
            Text("Owners and parents can change another member's role. Guests can be removed with a swipe.")
        }
    }

    @ViewBuilder
    private func memberRoleControl(_ member: HouseholdMemberSummary) -> some View {
        let roles = editableRoles(for: member)
        if roles.count > 1 {
            Menu {
                ForEach(roles, id: \.self) { role in
                    Button {
                        Task { await membersViewModel.updateRole(userId: member.userId, role: role) }
                    } label: {
                        if member.role == role {
                            Label(HouseholdRoles.roleLabel(role), systemImage: "checkmark")
                        } else {
                            Text(HouseholdRoles.roleLabel(role))
                        }
                    }
                    .disabled(membersViewModel.isWorking)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(HouseholdRoles.roleLabel(member.role))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(HubTheme.sageSoft)
                .foregroundStyle(HubTheme.sage)
                .clipShape(Capsule())
            }
            .disabled(membersViewModel.isWorking)
            .accessibilityLabel("Change role for \(member.name)")
        } else {
            Text(HouseholdRoles.roleLabel(member.role))
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(HubTheme.sageSoft)
                .clipShape(Capsule())
        }
    }

    private func editableRoles(for member: HouseholdMemberSummary) -> [HouseholdRole] {
        guard let actorRole = appState.household?.role,
              let actorUserId = appState.currentUser?.id else {
            return [member.role]
        }
        return HouseholdRoles.editableRoles(
            actorRole: actorRole,
            actorUserId: actorUserId,
            targetUserId: member.userId,
            targetRole: member.role,
            ownerCount: membersViewModel.members.filter { $0.role == .owner }.count
        )
    }

    private var profilesSection: some View {
        Group {
            if viewModel.isLoading && viewModel.profiles.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if viewModel.profiles.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Family profiles will appear here.")
                    )
                }
            } else {
                profileGroup(title: "Adults", profiles: viewModel.adultProfiles)
                profileGroup(title: "Children", profiles: viewModel.childProfiles)
            }

            if viewModel.canManage {
                Section {
                    Button {
                        viewModel.showAddForm = true
                        viewModel.selectedProfileId = nil
                        activeProfileEditor = .add(UUID())
                    } label: {
                        Label("Add Family Member", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func profileGroup(title: String, profiles: [Profile]) -> some View {
        Section(title) {
            ForEach(profiles) { profile in
                Button {
                    viewModel.showAddForm = false
                    viewModel.selectedProfileId = profile.id
                    activeProfileEditor = .edit(profile.id)
                } label: {
                    HStack {
                        ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text(profile.profileType.rawValue.capitalized)
                                if profile.userId != nil {
                                    Text("Linked account")
                                }
                                if let birthday = profile.birthday {
                                    Text(DateHelpers.formatLocalDate(birthday, timezone: viewModel.timezone, style: .medium))
                                }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(profile.name)")
            }
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case family
    case calendar
    case notifications
    case layout
    case data
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .family: "Family"
        case .calendar: "Calendar & Reminders"
        case .notifications: "Notifications"
        case .layout: "Layout"
        case .data: "Data & Sync"
        case .about: "About Beacon"
        }
    }

    var description: String {
        switch self {
        case .general: "Household details, date, appearance, and sign out."
        case .family: "Manage members and family profiles."
        case .calendar: "Access, defaults, alerts, and calendars on this device."
        case .notifications: "Configure native reminder times."
        case .layout: "Choose and arrange hub sections."
        case .data: "Check backend status and refresh local data."
        case .about: "Version, privacy, and terms."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .family: "person.2"
        case .calendar: "calendar"
        case .notifications: "bell.badge"
        case .layout: "rectangle.3.group"
        case .data: "arrow.triangle.2.circlepath"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: HubTheme.sage
        case .family: Color.blue
        case .calendar: Color.indigo
        case .notifications: Color.orange
        case .layout: Color.purple
        case .data: Color.green
        case .about: Color.gray
        }
    }
}

private struct SettingsIconTile: View {
    let tab: SettingsTab

    var body: some View {
        Image(systemName: tab.systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(tab.tint.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private enum ProfileEditorPresentation: Identifiable {
    case add(UUID)
    case edit(String)

    var id: String {
        switch self {
        case .add(let id):
            "add-\(id.uuidString)"
        case .edit(let profileId):
            "edit-\(profileId)"
        }
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let editor: ProfileEditorPresentation
    let profiles: [Profile]
    let timezone: TimeZone
    @ObservedObject var viewModel: ProfilesViewModel

    private var profile: Profile? {
        guard case .edit(let profileId) = editor else { return nil }
        return profiles.first { $0.id == profileId }
    }

    private var title: String {
        switch editor {
        case .add:
            "Add Family Member"
        case .edit:
            "Edit Profile"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch editor {
                    case .add:
                        ProfileFormView(
                            mode: .manage,
                            timezone: timezone,
                            submitLabel: "Add Member"
                        ) { input in
                            let saved = await viewModel.addProfile(input)
                            if saved {
                                dismiss()
                            }
                            return saved
                        }
                    case .edit:
                        if let profile {
                            ProfilePhotoUploadView(profile: profile) {
                                await viewModel.load()
                                await appState.refreshDashboard()
                            }
                            ProfileFormView(
                                profile: profile,
                                mode: .manage,
                                timezone: timezone,
                                submitLabel: "Save Changes"
                            ) { input in
                                let saved = await viewModel.updateProfile(id: profile.id, input: input)
                                if saved {
                                    dismiss()
                                }
                                return saved
                            }
                        } else {
                            ContentUnavailableView(
                                "Profile Missing",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text("This profile could not be found.")
                            )
                        }
                    }
                }
                .padding()
            }
            .background(HubTheme.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct NativeNotificationsSettingView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var service: NativeNotificationService

    var body: some View {
        Form {
            Section {
                permissionRow
            } header: {
                Text("Local Reminders")
            } footer: {
                Text("Beacon can remind this device about routines, chores, bedtime, and active naps without relying on server jobs.")
            }

            Section("Routines") {
                Toggle("Routine Reminders", isOn: boolBinding(\.routinesEnabled))
                timeRow("Morning", systemImage: "sun.max.fill", minute: \.morningRoutineMinute)
                timeRow("Afternoon", systemImage: "sun.haze.fill", minute: \.afternoonRoutineMinute)
                timeRow("Bedtime", systemImage: "moon.fill", minute: \.eveningRoutineMinute)
            }

            Section("Chores") {
                Toggle("Chore Check-In", isOn: boolBinding(\.choresEnabled))
                timeRow("Daily Check-In", systemImage: "checkmark.square.fill", minute: \.choreMinute)
            }

            Section("Sleep") {
                Toggle("Sleep Reminders", isOn: boolBinding(\.sleepEnabled))
                timeRow("Bedtime", systemImage: "bed.double.fill", minute: \.bedtimeMinute)
                Stepper(value: intBinding(\.napCheckMinutes), in: 30...180, step: 15) {
                    Label("Nap Check After \(service.settings.napCheckMinutes) Minutes", systemImage: "timer")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await service.refreshAccessStatus()
            await appState.rescheduleNativeNotifications()
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        switch service.accessStatus {
        case .notDetermined:
            Button {
                Task {
                    await service.requestAuthorization()
                    await appState.rescheduleNativeNotifications()
                }
            } label: {
                Label("Allow notifications", systemImage: "bell.fill")
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
        case .denied:
            Label("Notifications are off. Turn them on in Settings to use local reminders.", systemImage: "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
        case .authorized, .provisional, .ephemeral:
            Label("Notifications are enabled on this device.", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HubTheme.sage)
        }
    }

    private func timeRow(
        _ title: String,
        systemImage: String,
        minute keyPath: WritableKeyPath<HomeHubNotificationSettings, Int>
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Spacer()
            DatePicker(
                title,
                selection: dateBinding(keyPath),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<HomeHubNotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { service.settings[keyPath: keyPath] },
            set: { value in
                var next = service.settings
                next[keyPath: keyPath] = value
                service.settings = next
                Task { await appState.rescheduleNativeNotifications() }
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<HomeHubNotificationSettings, Int>) -> Binding<Int> {
        Binding(
            get: { service.settings[keyPath: keyPath] },
            set: { value in
                var next = service.settings
                next[keyPath: keyPath] = value
                service.settings = next
                Task { await appState.rescheduleNativeNotifications() }
            }
        )
    }

    private func dateBinding(_ keyPath: WritableKeyPath<HomeHubNotificationSettings, Int>) -> Binding<Date> {
        Binding(
            get: { date(fromMinute: service.settings[keyPath: keyPath]) },
            set: { value in
                var calendar = Calendar.current
                calendar.timeZone = appState.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
                let components = calendar.dateComponents([.hour, .minute], from: value)
                var next = service.settings
                next[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                service.settings = next
                Task { await appState.rescheduleNativeNotifications() }
            }
        )
    }

    private func date(fromMinute minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = appState.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
        let now = Date()
        return calendar.date(
            bySettingHour: max(0, min(23, minute / 60)),
            minute: max(0, min(59, minute % 60)),
            second: 0,
            of: now
        ) ?? now
    }
}

private struct HubModulesSettingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var modules = HubModules.defaults
    @State private var draggedLayoutItem: String?
    @State private var dropTargetItem: String?
    @State private var pendingDraggedModules: HubModules?
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HubCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Layout", systemImage: "rectangle.3.group")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HubTheme.sage)

                    Text("Choose which sections appear, then arrange the order used by the sidebar and dashboard. The sidebar automatically moves extra buttons into More on smaller screens.")
                        .font(.footnote)
                        .foregroundStyle(HubTheme.muted)
                }
            }

            layoutGroup(
                title: "Sidebar sections",
                description: "Today and Settings stay fixed. These sections can be hidden or reordered.",
                items: modules.sidebarOrder,
                isEnabled: { modules.isEnabled($0) },
                label: { $0.label },
                systemImage: { $0.systemImage },
                toggle: { module, enabled in
                    var next = modules.updating(module, enabled: enabled)
                    if module == .meals && !enabled {
                        next = next.updating(.snacks, enabled: false).updating(.recipes, enabled: false)
                    }
                    updateModules(next)
                },
                moveBefore: reorderSidebarModule,
                moveBy: moveSidebarModule
            )

            layoutGroup(
                title: "Food tabs",
                description: "Weekly meals stays inside Food. Snacks and Recipes can be hidden.",
                items: HubModules.foodModules,
                isEnabled: { modules.isEnabled($0) },
                label: { $0.label },
                systemImage: { $0.systemImage },
                toggle: { module, enabled in
                    let next = modules.updating(module, enabled: enabled)
                    updateModules(next)
                },
                moveBefore: nil,
                moveBy: nil
            )

            layoutGroup(
                title: "Dashboard cards",
                description: "Cards follow this order and wrap to fit the device.",
                items: modules.dashboardOrder,
                isEnabled: { modules.dashboardCards[$0, default: true] },
                label: { $0.label },
                systemImage: { $0.systemImage },
                toggle: { card, enabled in
                    let next = modules.updatingDashboardCard(card, enabled: enabled)
                    updateModules(next)
                },
                moveBefore: reorderDashboardCard,
                moveBy: moveDashboardCard
            )

            Button("Reset layout") {
                updateModules(.defaults)
            }
            .buttonStyle(HubButtonStyle(emphasis: .secondary))
            .disabled(isSaving)
        }
        .onAppear {
            modules = appState.hubModules
        }
        .onChange(of: appState.hubModules) { _, newValue in
            if !isSaving {
                modules = newValue
            }
        }
    }

    private func layoutGroup<Item: Hashable & RawRepresentable>(
        title: String,
        description: String,
        items: [Item],
        isEnabled: @escaping (Item) -> Bool,
        label: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String,
        toggle: @escaping (Item, Bool) -> Void,
        moveBefore: ((Item, Item) -> HubModules?)?,
        moveBy: ((Item, Int) -> Void)?
    ) -> some View where Item.RawValue == String {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)

                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    LayoutOptionRow(
                        title: label(item),
                        systemImage: systemImage(item),
                        isOn: Binding(
                            get: { isEnabled(item) },
                            set: { toggle(item, $0) }
                        ),
                        isDragging: draggedLayoutItem == rawValue(item),
                        isDropTarget: dropTargetItem == rawValue(item),
                        canReorder: moveBefore != nil,
                        canMoveUp: index > 0,
                        canMoveDown: index < items.count - 1,
                        moveUp: { moveBy?(item, -1) },
                        moveDown: { moveBy?(item, 1) },
                        dragProvider: moveBefore == nil ? nil : {
                            draggedLayoutItem = rawValue(item)
                            return NSItemProvider(object: rawValue(item) as NSString)
                        }
                    )
                    .onDrop(
                        of: [UTType.plainText.identifier],
                        delegate: LayoutReorderDropDelegate(
                            targetValue: rawValue(item),
                            draggedValue: $draggedLayoutItem,
                            dropTargetValue: $dropTargetItem,
                            onMoveBefore: { draggedValue, targetValue in
                                guard draggedValue != targetValue,
                                      let draggedItem = items.first(where: { rawValue($0) == draggedValue }),
                                      let targetItem = items.first(where: { rawValue($0) == targetValue }) else {
                                    return
                                }
                                if let next = moveBefore?(draggedItem, targetItem) {
                                    pendingDraggedModules = next
                                }
                            },
                            onCommit: {
                                let next = pendingDraggedModules ?? modules
                                pendingDraggedModules = nil
                                updateModules(next)
                            }
                        )
                    )
                }
            }
        }
    }

    private func rawValue<Item: RawRepresentable>(_ item: Item) -> String where Item.RawValue == String {
        item.rawValue
    }

    private func reorderSidebarModule(_ dragged: HubModuleId, before target: HubModuleId) -> HubModules? {
        let nextOrder = moving(dragged, before: target, in: modules.sidebarOrder)
        guard nextOrder != modules.sidebarOrder else { return nil }
        var next = modules
        next.sidebarOrder = nextOrder
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        return next
    }

    private func reorderDashboardCard(_ dragged: DashboardCardId, before target: DashboardCardId) -> HubModules? {
        let nextOrder = moving(dragged, before: target, in: modules.dashboardOrder)
        guard nextOrder != modules.dashboardOrder else { return nil }
        var next = modules
        next.dashboardOrder = nextOrder
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        return next
    }

    private func moveSidebarModule(_ module: HubModuleId, by offset: Int) {
        let next = modules.movingSidebarModule(module, by: offset)
        guard next != modules else { return }
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        updateModules(next)
    }

    private func moveDashboardCard(_ card: DashboardCardId, by offset: Int) {
        let next = modules.movingDashboardCard(card, by: offset)
        guard next != modules else { return }
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        updateModules(next)
    }

    private func moving<Item: Equatable>(_ dragged: Item, before target: Item, in order: [Item]) -> [Item] {
        guard let sourceIndex = order.firstIndex(of: dragged),
              let targetIndex = order.firstIndex(of: target),
              sourceIndex != targetIndex else {
            return order
        }

        var copy = order
        let item = copy.remove(at: sourceIndex)
        copy.insert(item, at: targetIndex)
        return copy
    }

    @MainActor
    private func updateModules(_ next: HubModules) {
        saveTask?.cancel()
        isSaving = true
        modules = next
        appState.applyHubModules(next)
        saveTask = Task { @MainActor in
            await appState.saveHubModules(next)
            guard !Task.isCancelled else { return }
            isSaving = false
        }
    }
}

private struct LayoutOptionRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var isDragging = false
    var isDropTarget = false
    var canReorder = false
    var canMoveUp = false
    var canMoveDown = false
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?
    var dragProvider: (() -> NSItemProvider)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(HubTheme.sage)
                .frame(width: 30, height: 30)
                .background(HubTheme.sageSoft)
                .clipShape(Circle())

            Toggle(title, isOn: $isOn)
                .font(.subheadline.weight(.semibold))

            if canReorder {
                dragHandle
            }
        }
        .padding(12)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isDropTarget ? HubTheme.sage.opacity(0.55) : Color.clear, lineWidth: 1.5)
        )
        .opacity(isDragging ? 0.42 : 1)
        .scaleEffect(isDragging ? 0.98 : 1)
        .shadow(color: isDragging ? HubTheme.sage.opacity(0.18) : .clear, radius: 10, y: 4)
        .accessibilityAction(named: Text("Move \(title) up")) { if canMoveUp { moveUp?() } }
        .accessibilityAction(named: Text("Move \(title) down")) { if canMoveDown { moveDown?() } }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.bold))
            .foregroundStyle(HubTheme.muted)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .onDrag {
                dragProvider?() ?? NSItemProvider()
            } preview: {
                dragPreview
            }
            .accessibilityLabel("Reorder \(title)")
            .accessibilityHint("Drag to change the order.")
    }

    private var dragPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(HubTheme.sage)
                .frame(width: 28, height: 28)
                .background(HubTheme.sageSoft)
                .clipShape(Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(HubTheme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 280, alignment: .leading)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}

private struct LayoutReorderDropDelegate: DropDelegate {
    let targetValue: String
    @Binding var draggedValue: String?
    @Binding var dropTargetValue: String?
    let onMoveBefore: (String, String) -> Void
    let onCommit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedValue, draggedValue != targetValue else { return }
        dropTargetValue = targetValue
        onMoveBefore(draggedValue, targetValue)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedValue = nil
        dropTargetValue = nil
        onCommit()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetValue == targetValue {
            dropTargetValue = nil
        }
    }
}
