import SwiftUI
import UIKit
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
    @State private var exportDocument: HouseholdExportDocument?
    @State private var isPreparingExport = false
    @State private var showExporter = false
    @State private var confirmingSignOut = false
    @State private var guestToRemove: HouseholdMemberSummary?

    var body: some View {
        Group {
            if presentation == .split {
                NavigationStack {
                    // The page title is drawn like every other iPad page's, instead of a system large title
                    // that reserved an empty navigation bar's worth of space above it. Pushed pages
                    // (General, Family, …) still get their own bar and back button.
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Settings")
                            .font(HubTheme.pageTitle)
                            .padding(.horizontal, 20)
                            .accessibilityAddTraits(.isHeader)
                        settingsContent
                    }
                    .hubPageBackground()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
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
            if appState.needsEmailVerification {
                Section {
                    VerifyEmailCard()
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            statusMessagesSection

            Section {
                settingsRow(.general)
                settingsRow(.family)
            } header: {
                Text("Household")
            }

            Section {
                settingsRow(.notifications)
                settingsRow(.layout)
                settingsRow(.calendar)
                settingsRow(.appearance)
                settingsRow(.privacyAccess)
            } header: {
                Text("Beacon")
            }

            Section {
                settingsRow(.faq)
                settingsRow(.data)
                settingsRow(.about)
            } header: {
                Text("Support")
            }
        }
        .scrollContentBackground(.hidden)
        .hubPageBackground()
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
                        .foregroundStyle(HubTheme.accentText)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var permissionsSummarySection: some View {
        Section {
            LabeledContent("Role", value: appState.household.map { HouseholdRoles.roleLabel($0.role) } ?? "Signed out")
            LabeledContent("Household setup", value: appState.canManageHousehold ? "Can manage" : "View only")
            LabeledContent("Calendar & Reminders", value: appState.canManageHousehold ? "Can configure" : "Can use")
        } footer: {
            Text("Owners and parents manage shared household setup. Guests can use the household views without changing global settings.")
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
            nil
        case .appearance:
            appState.accentPalette.label
        case .privacyAccess:
            permissionSummaryLabel
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
            "\(DashboardCardId.allCases.filter { $0 != .weather }.count)"
        case .data:
            appState.household == nil ? "Offline" : "Signed in"
        case .faq:
            nil
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
            Text(success).font(.footnote).foregroundStyle(HubTheme.accentText)
        }
        if let membersError = membersViewModel.errorMessage {
            Text(membersError).font(.footnote).foregroundStyle(.red)
        }
        if let membersSuccess = membersViewModel.successMessage {
            Text(membersSuccess).font(.footnote).foregroundStyle(HubTheme.accentText)
        }
    }

    @ViewBuilder
    private func settingsPage(_ tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalTab
        case .appearance:
            appearanceTab
        case .privacyAccess:
            PrivacyAccessSettingsView(
                calendar: appState.nativeCalendar,
                reminders: appState.nativeReminders,
                notifications: appState.nativeNotifications,
                weather: appState.nativeWeather
            )
        case .family:
            usersTab
        case .calendar:
            CalendarSettingsView()
        case .notifications:
            NativeNotificationsSettingView(service: appState.nativeNotifications)
        case .layout:
            HubModulesSettingView()
        case .data:
            dataTab
        case .faq:
            SettingsFAQView()
        case .about:
            aboutTab
        }
    }

    private var generalTab: some View {
        Form {
            permissionsSummarySection

            if let household = appState.household {
                householdSection(household)
            }

            if appState.household != nil {
                dateSection
            }

            if appState.canManageHousehold {
                exportSection
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    confirmingSignOut = true
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .confirmationDialog("Sign out of Beacon?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
        } message: {
            Text("The household's information stays safe. Sign back in any time.")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "beacon-export-\(DateHelpers.localDateIn(timezone: .current))"
        ) { result in
            if case .failure(let error) = result {
                appState.report(error)
            }
            exportDocument = nil
        }
        .onAppear {
            if let household = appState.household {
                weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            }
        }
    }

    private var permissionSummaryLabel: String {
        let enabledCount = [
            appState.nativeCalendar.hasFullAccess,
            appState.nativeReminders.hasFullAccess,
            appState.nativeNotifications.canSchedule,
            appState.nativeWeather.accessStatus == .authorized
        ].filter { $0 }.count
        return "\(enabledCount) of 4"
    }

    private var appearanceTab: some View {
        Form {
            ThemeSettingView()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
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
            appState.report(error)
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

                // The server sends empty codes to guests, who can't invite anyone.
                if !household.inviteCode.isEmpty {
                    InviteCodesSection(household: household)
                }
            }

            if appState.canManageHousehold {
                membersSection
            }

            profilesSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .confirmationDialog(
            "Remove \(guestToRemove?.name ?? "this guest")?",
            isPresented: Binding(get: { guestToRemove != nil }, set: { if !$0 { guestToRemove = nil } }),
            titleVisibility: .visible,
            presenting: guestToRemove
        ) { guest in
            Button("Remove Guest", role: .destructive) {
                Task { await membersViewModel.removeGuest(userId: guest.userId) }
            }
        } message: { _ in
            Text("They lose access to the household now. They can rejoin with the guest code unless you replace it.")
        }
    }

    private var dataTab: some View {
        Form {
            Section {
                LabeledContent("Server", value: AppConfig.baseURL.absoluteString)
                LabeledContent("Session", value: appState.currentUser == nil ? "Signed out" : "Signed in")
                LabeledContent("Local cache", value: appState.dashboard == nil ? "Empty" : "Ready")
            } header: {
                Text("Sync Status")
            } footer: {
                Text("Beacon keeps your household's information on its server and uses this device for calendars, reminders, weather, and notifications.")
            }

            Section {
                Button {
                    Task {
                        // The dashboard carries the household, so this one call is enough; forcing it
                        // also re-reads the device's calendars, reminders and weather.
                        await appState.refreshDashboard(forcingDeviceRefresh: true)
                    }
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
    }

    private var aboutTab: some View {
        Form {
            Section {
                LabeledContent("Version", value: appVersionLabel)
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
        .hubPageBackground()
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

    private var exportSection: some View {
        Section {
            Button {
                Task { await prepareExport() }
            } label: {
                Label(isPreparingExport ? "Preparing Export" : "Export Household Data", systemImage: "square.and.arrow.up")
            }
            .disabled(isPreparingExport)
        } footer: {
            Text("Saves a JSON file with your profiles, routines, chores, meals, recipes, groceries, notes, birthdays, and sleep logs. Invite codes and email addresses are not included.")
        }
    }

    private func prepareExport() async {
        isPreparingExport = true
        defer { isPreparingExport = false }
        do {
            exportDocument = HouseholdExportDocument(data: try await appState.api.exportHouseholdData())
            showExporter = true
        } catch {
            appState.report(error)
        }
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
                                guestToRemove = member
                            } label: {
                                Label("Remove", systemImage: "person.crop.circle.badge.minus")
                            }
                            .disabled(membersViewModel.isWorking)
                        }
                    }
                    .contextMenu {
                        if member.role == .guest {
                            Button(role: .destructive) {
                                guestToRemove = member
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
                .foregroundStyle(HubTheme.accentText)
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

private struct SettingsFAQView: View {
    @State private var searchText = ""
    @State private var expandedQuestions: Set<String> = []

    private var filteredSections: [FAQSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.sections }
        return Self.sections.compactMap { section in
            let questions = section.questions.filter {
                "\(section.title) \($0.question) \($0.answer)".localizedStandardContains(query)
            }
            return questions.isEmpty ? nil : FAQSection(title: section.title, questions: questions)
        }
    }

    var body: some View {
        List {
            ForEach(filteredSections) { section in
                Section(section.title) {
                    ForEach(section.questions) { item in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedQuestions.contains(item.id) },
                            set: { expanded in
                                if expanded {
                                    expandedQuestions.insert(item.id)
                                } else {
                                    expandedQuestions.remove(item.id)
                                }
                            }
                        )) {
                            Text(item.answer)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .padding(.vertical, 6)
                        } label: {
                            Text(item.question)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .searchable(text: $searchText, prompt: "Search questions")
        .overlay {
            if filteredSections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private struct FAQSection: Identifiable {
        let title: String
        let questions: [FAQItem]
        var id: String { title }
    }

    private struct FAQItem: Identifiable {
        let question: String
        let answer: String
        var id: String { question }

        init(_ question: String, _ answer: String) {
            self.question = question
            self.answer = answer
        }
    }

    private static let sections: [FAQSection] = [
        FAQSection(title: "Getting Started", questions: [
            FAQItem("How do I use Beacon on more than one device?", "Install Beacon on each device and sign in. Use the same account, or have another parent create an account and join your household with the parent invite code in Settings > Family. Shared household information is the same on your phone and your iPad."),
            FAQItem("What is the difference between an account and a family profile?", "An account is a sign-in for someone using Beacon. A family profile represents a person in your household, including children who do not need their own sign-in. Profiles let you assign routines and chores and keep birthdays together."),
            FAQItem("How do I invite a parent or helper?", "Find the invite codes in Settings > Family. Share the parent code with another parent, or the guest code with a helper. They create an account and join with that code. Treat invite codes as private household information."),
            FAQItem("What can owners, parents, and guests do?", "Owners and parents manage household setup and family information. Guests can use household views without changing global settings. Your role and available permissions appear in Settings > General.")
        ]),
        FAQSection(title: "Today & Layout", questions: [
            FAQItem("How do I choose and arrange Today cards?", "Open Settings > Layout > Today Cards. Toggle the cards you want to see and use the reorder controls to arrange them. Your card choices and order are saved for your signed-in user."),
            FAQItem("What do Standard and Expanded mean?", "Standard takes one column and Expanded takes two, when there is room. On iPhone that is half the width or the full width of the screen. Expanded changes width rather than making a card taller."),
            FAQItem("What do Set as Default and Restore Default do?", "At the bottom of Settings > Layout > Today Cards, Set as Default saves your current Today layout (which cards are on, their order, and their sizes) for iPhone or for iPad & Mac, whichever you are editing. Restore Default brings it back after the cards have been moved around. It is saved on the device you set it on, and which cards are switched on is shared with your other devices."),
            FAQItem("Do my layout choices follow me between iPhone and iPad?", "Yes. Layout preferences are saved to your account, so the same user can use them on iPhone and iPad. Another parent has their own layout preferences. Each device adapts the arrangement to its available space."),
            FAQItem("Where are the sections I cannot see in navigation?", "Tap More to see overflow sections. Larger screens show more sections directly when space allows. Open Settings > Layout > Navigation to choose and reorder optional sections; Today stays available.")
        ]),
        FAQSection(title: "Calendars & Reminders", questions: [
            FAQItem("How do I connect my calendar?", "Open Settings > Calendar & Reminders and allow native calendar access. Beacon reads the calendars available in Apple Calendar on that device. Add iCloud, Google, or other accounts to the device's Calendar settings first; you do not sign in to those providers inside Beacon."),
            FAQItem("How do I choose which calendars appear?", "In Settings > Calendar & Reminders, open the calendar selection and choose from the accessible device calendars. Save your selection, or select all calendars. Configure calendar access and selection separately on each device."),
            FAQItem("Why are events different on my phone and iPad?", "Calendars are read locally through Apple Calendar. Check that both devices have the same calendar accounts, that the calendars are syncing in Apple Calendar, and that Beacon has access and the intended calendars selected on each device. Joining the same Beacon household does not share a calendar account."),
            FAQItem("How do I switch between day, week, and month?", "Open Calendar and select Day, Week, or Month. Tap a date in the grid to open Day view, or tap an event to see its details. Use the previous and next controls to move through dates, or Today to return to the current date. Search filters the events in the current calendar range."),
            FAQItem("How do groceries work with Apple Reminders?", "Allow Reminders access in Settings > Calendar & Reminders and choose a list. Beacon uses that device's selected Reminders list. To see the same items elsewhere, share or sync the list through Apple Reminders and select it on each device. Without Reminders access, Beacon uses its own household grocery list; these are separate lists."),
            FAQItem("What if I denied Calendar or Reminders access?", "Open the permission settings from Beacon's Calendar & Reminders page, or open iOS Settings and find Beacon. Enable access, then return to Beacon and refresh. Calendars and lists must also be available in the Apple apps on that device.")
        ]),
        FAQSection(title: "Routines, Chores & Food", questions: [
            FAQItem("How do I organize routines by child?", "Create or edit a routine in Routines and assign it to the child's family profile. Add the steps and choose a period. The Today routines card groups assigned steps by person and shows completion progress with a ring and count."),
            FAQItem("How do I complete a routine or chore?", "Open Routines or Chores and tap the completion control beside the step or chore. Tap it again to undo. Routine completion is tracked by date; chore completion follows its daily or weekly cadence."),
            FAQItem("How do I plan meals and use recipes?", "Open Food to plan meals. Tap a slot to pick a saved recipe or a recently used meal, or type your own. Changes save automatically. Use the arrows to plan other weeks, swipe a meal to clear it or copy it to tomorrow, and press and hold to drag it to another slot. Add Week to Groceries in the More menu turns the week's recipes into a shopping list. Recipes supports adding a recipe manually or importing from a URL. If a site cannot be imported, enter the recipe manually."),
            FAQItem("How do I change the snack checklist?", "Open Snacks to edit the snack options if you are an owner or parent. Tap the checklist controls to record snacks for the day. Reset the day's checklist when you need to clear those selections.")
        ]),
        FAQSection(title: "Sync & Troubleshooting", questions: [
            FAQItem("When does shared information refresh?", "Beacon loads shared data when it starts and when screens load or refresh. Edits refresh the relevant data on the device making the change. Other devices receive changes when they fetch fresh data; this is not a continuous live connection. Use Settings > Data & Sync > Refresh Now if a device looks out of date."),
            FAQItem("Can I use Beacon offline?", "Beacon can show cached household and Today content when it is available. Shared household edits need a working connection; do not assume offline edits will be queued and uploaded later. Native calendars and Reminders depend on what is available locally on your device."),
            FAQItem("Why is weather unavailable?", "Weather needs device location access and an available weather service. Allow location access when prompted, check Beacon's permissions in system settings, and make sure the device has a connection. Weather may be unavailable on some devices or environments."),
            FAQItem("Why am I not receiving reminders?", "Open Settings > Notifications in Beacon, allow notifications, and enable the reminders and times you want. Also check the device's notification settings, Focus modes, and Scheduled Summary. Beacon's reminder preferences and notification permission are configured on each device."),
            FAQItem("How do I change colors or light and dark mode?", "Open Settings > Appearance to choose Automatic, Light or Dark, switch on True Black for pure black pages in dark mode, pick a theme color, or change the app icon. Automatic follows your device's setting. These choices apply only to the device you make them on.")
        ])
    ]
}

private struct PrivacyAccessSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var calendar: NativeCalendarService
    @ObservedObject var reminders: NativeRemindersService
    @ObservedObject var notifications: NativeNotificationService
    @ObservedObject var weather: NativeWeatherService

    var body: some View {
        Form {
            Section {
                PermissionAccessRow(
                    title: "Calendars",
                    detail: "Shows events from calendars available on this device.",
                    systemImage: "calendar",
                    state: calendarPermissionState,
                    actionTitle: actionTitle(for: calendarPermissionState)
                ) {
                    if calendar.accessStatus == .notDetermined {
                        await calendar.requestFullAccess()
                    } else {
                        openSystemSettings()
                    }
                }

                PermissionAccessRow(
                    title: "Reminders",
                    detail: "Adds grocery items to an Apple Reminders list.",
                    systemImage: "checklist",
                    state: remindersPermissionState,
                    actionTitle: actionTitle(for: remindersPermissionState)
                ) {
                    if reminders.accessStatus == .notDetermined {
                        await reminders.requestFullAccess()
                    } else {
                        openSystemSettings()
                    }
                }

                PermissionAccessRow(
                    title: "Notifications",
                    detail: "Delivers routine, chore, bedtime, and nap reminders.",
                    systemImage: "bell.badge",
                    state: notificationPermissionState,
                    actionTitle: actionTitle(for: notificationPermissionState)
                ) {
                    if notifications.accessStatus == .notDetermined {
                        await notifications.requestAuthorization()
                    } else {
                        openSystemSettings()
                    }
                }

                PermissionAccessRow(
                    title: "Location",
                    detail: "Uses approximate device location to show local weather.",
                    systemImage: "location.fill",
                    state: locationPermissionState,
                    actionTitle: actionTitle(for: locationPermissionState)
                ) {
                    if weather.accessStatus == .notDetermined {
                        await weather.requestAccessAndRefresh()
                    } else {
                        openSystemSettings()
                    }
                }
            } header: {
                Text("Device Access")
            } footer: {
                Text("These permissions apply only to this device. Beacon does not upload calendar or reminder contents to its server.")
            }

            Section {
                Button {
                    openSystemSettings()
                } label: {
                    Label("Open Beacon in iOS Settings", systemImage: "gearshape")
                }
            } footer: {
                Text("Use iOS Settings to restore access after a permission has been denied or to change an existing choice.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .task {
            await refreshPermissionStatuses()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPermissionStatuses() }
        }
    }

    private var calendarPermissionState: DevicePermissionState {
        switch calendar.accessStatus {
        case .authorized: .allowed
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    private var remindersPermissionState: DevicePermissionState {
        switch reminders.accessStatus {
        case .authorized: .allowed
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    private var notificationPermissionState: DevicePermissionState {
        switch notifications.accessStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .notDetermined: .notRequested
        case .denied: .denied
        }
    }

    private var locationPermissionState: DevicePermissionState {
        switch weather.accessStatus {
        case .authorized: .allowed
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        case .unavailable: .unavailable
        }
    }

    private func actionTitle(for state: DevicePermissionState) -> String? {
        switch state {
        case .notRequested: "Allow"
        case .allowed, .denied, .restricted: "Open Settings"
        case .unavailable: nil
        }
    }

    private func refreshPermissionStatuses() async {
        calendar.refreshAccessStatus()
        reminders.refreshAccessStatus()
        await notifications.refreshAccessStatus()
        await weather.activateIfAuthorized()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct PermissionAccessRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let state: DevicePermissionState
    let actionTitle: String?
    let action: () async -> Void

    @State private var isWorking = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)
                .frame(width: 34, height: 34)
                .background(HubTheme.sageSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(state.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(state.foregroundStyle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(state.backgroundStyle, in: Capsule())

                if let actionTitle {
                    Button(actionTitle) {
                        Task {
                            isWorking = true
                            await action()
                            isWorking = false
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private enum DevicePermissionState {
    case allowed
    case notRequested
    case denied
    case restricted
    case unavailable

    var label: String {
        switch self {
        case .allowed: "Allowed"
        case .notRequested: "Not Asked"
        case .denied: "Off"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .allowed: HubTheme.accentText
        case .notRequested: .orange
        case .denied, .restricted: .red
        case .unavailable: .secondary
        }
    }

    var backgroundStyle: Color {
        switch self {
        case .allowed: HubTheme.sageSoft
        case .notRequested: Color.orange.opacity(0.14)
        case .denied, .restricted: Color.red.opacity(0.12)
        case .unavailable: Color.secondary.opacity(0.12)
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case privacyAccess
    case family
    case calendar
    case notifications
    case layout
    case data
    case faq
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .privacyAccess: "Privacy & Access"
        case .family: "Family"
        case .calendar: "Calendar & Reminders"
        case .notifications: "Notifications"
        case .layout: "Layout"
        case .data: "Data & Sync"
        case .faq: "FAQ & Help"
        case .about: "About Beacon"
        }
    }

    var description: String {
        switch self {
        case .general: "Household details, date, and sign out."
        case .appearance: "Theme, mode, and app icon."
        case .privacyAccess: "Review permissions used on this device."
        case .family: "Manage members and family profiles."
        case .calendar: "Access, defaults, alerts, and calendars on this device."
        case .notifications: "Configure native reminder times."
        case .layout: "Choose and arrange hub sections."
        case .data: "Check the connection and refresh your data."
        case .faq: "Getting started, everyday use, and troubleshooting."
        case .about: "Version, privacy, and terms."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .privacyAccess: "hand.raised"
        case .family: "person.2"
        case .calendar: "calendar"
        case .notifications: "bell.badge"
        case .layout: "rectangle.3.group"
        case .data: "arrow.triangle.2.circlepath"
        case .faq: "questionmark.circle"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: HubTheme.sage
        case .appearance: Color.pink
        case .privacyAccess: Color.cyan
        case .family: Color.blue
        case .calendar: Color.indigo
        case .notifications: Color.orange
        case .layout: Color.purple
        case .data: Color.green
        case .faq: Color.teal
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
                Text("Beacon can remind this device about routines, chores, bedtime, active naps, and birthdays and anniversaries without relying on server jobs.")
            }

            Section("Routines") {
                Toggle("Routine Reminders", isOn: boolBinding(\.routinesEnabled))
                timeRow("Morning", systemImage: "sun.max.fill", minute: \.morningRoutineMinute)
                timeRow("Afternoon", systemImage: "sun.haze.fill", minute: \.afternoonRoutineMinute)
                timeRow("Bedtime", systemImage: "moon.fill", minute: \.eveningRoutineMinute)
            }

            Section {
                Toggle("Chore Check-In", isOn: boolBinding(\.choresEnabled))
                timeRow("Daily Check-In", systemImage: "checkmark.square.fill", minute: \.choreMinute)
                Picker(selection: intBinding(\.choreLeadMinutes)) {
                    ForEach(ChoreReminderPlanner.leadChoices, id: \.self) { minutes in
                        Text(ChoreReminderPlanner.leadLabel(minutes)).tag(minutes)
                    }
                } label: {
                    Label("Timed Chores", systemImage: "alarm.fill")
                        .font(.subheadline.weight(.semibold))
                }
            } header: {
                Text("Chores")
            } footer: {
                Text("A chore with a time reminds you by name, ahead of time if you choose. The check-in covers chores with no time. Reminders for the next few days are planned in advance, so they still arrive if you don't open the app.")
            }

            Section("Sleep") {
                Toggle("Sleep Reminders", isOn: boolBinding(\.sleepEnabled))
                timeRow("Bedtime", systemImage: "bed.double.fill", minute: \.bedtimeMinute)
                Stepper(value: intBinding(\.napCheckMinutes), in: 30...180, step: 15) {
                    Label("Nap Check After \(service.settings.napCheckMinutes) Minutes", systemImage: "timer")
                }
            }

            if appState.hubModules.isEnabled(.birthdays) {
                Section {
                    Toggle(CelebrationNaming.currentRemindersTitle, isOn: boolBinding(\.birthdaysEnabled))
                    if service.settings.birthdaysEnabled {
                        Toggle("On the Day", isOn: boolBinding(\.birthdayOnTheDay))
                        ForEach(BirthdayNotificationPlanner.leadDayChoices, id: \.self) { days in
                            Toggle(BirthdayNotificationPlanner.leadLabel(days), isOn: leadDaysBinding(days))
                        }
                        timeRow("Send At", systemImage: "clock.fill", minute: \.birthdayMinute)
                    }
                } header: {
                    Text(CelebrationNaming.current)
                } footer: {
                    Text("Pick as many reminders as you like. Beacon plans them up to 45 days ahead, so they still arrive if you don't open the app, using the household's time zone.")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .hubPageBackground()
        .task {
            // Reminders are already planned; only re-plan if the permission changed while away
            // (for instance in iOS Settings).
            let before = service.accessStatus
            await service.refreshAccessStatus()
            if service.accessStatus != before {
                await appState.rescheduleNativeNotifications()
            }
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
                .foregroundStyle(HubTheme.accentText)
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

    private func leadDaysBinding(_ days: Int) -> Binding<Bool> {
        Binding(
            get: { service.settings.birthdayLeadDays.contains(days) },
            set: { isOn in
                var next = service.settings
                var lead = Set(next.birthdayLeadDays)
                if isOn {
                    lead.insert(days)
                } else {
                    lead.remove(days)
                }
                next.birthdayLeadDays = lead.sorted()
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var modules = HubModules.defaults
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var editingTarget: DashboardLayoutTarget = .phone
    @State private var confirmingReset = false
    @State private var confirmingRestoreDefault = false
    /// The layout saved as this person's default for the kind of device being edited, if any.
    @State private var savedDefault: TodayLayoutDefault?

    var body: some View {
        layoutRoot
            .onAppear {
                modules = appState.hubModules
                editingTarget = DashboardLayoutTarget(horizontalSizeClass: horizontalSizeClass)
                loadSavedDefault()
            }
            .onChange(of: editingTarget) { _, _ in loadSavedDefault() }
            .onChange(of: appState.hubModules) { _, newValue in
                if !isSaving {
                    modules = newValue
                }
            }
    }

    private var layoutRoot: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HubCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Layout", systemImage: "rectangle.3.group")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(HubTheme.accentText)

                        Text("Fine-tune what appears in Today, the sidebar, and Food. Your changes save automatically.")
                            .font(.footnote)
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                HubCard {
                    VStack(spacing: 0) {
                        layoutSectionLink(.todayCards)
                        Divider().padding(.leading, 50)
                        layoutSectionLink(.navigation)
                        Divider().padding(.leading, 50)
                        layoutSectionLink(.food)
                    }
                }

                Button("Reset layout") {
                    confirmingReset = true
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
                .disabled(isSaving)
                .confirmationDialog("Reset the layout?", isPresented: $confirmingReset, titleVisibility: .visible) {
                    Button("Reset Layout", role: .destructive) {
                        updateModules(.defaults)
                    }
                } message: {
                    Text("Today cards and navigation go back to their defaults on iPhone and iPad.")
                }
            }
            .padding()
        }
        .background(HubTheme.canvas)
        .navigationDestination(for: LayoutSettingsSection.self) { section in
            layoutSectionPage(section)
                .navigationTitle(section.title)
                .navigationBarTitleDisplayMode(.inline)
                .background(HubTheme.canvas)
        }
    }

    private func layoutSectionLink(_ section: LayoutSettingsSection) -> some View {
        NavigationLink(value: section) {
            HStack(spacing: 14) {
                Image(systemName: section.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
                    .frame(width: 34, height: 34)
                    .background(HubTheme.sageSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.body.weight(.semibold))
                    Text(section.description)
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(section.summary(modules))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func layoutSectionPage(_ section: LayoutSettingsSection) -> some View {
        // A real List so reordering is the system's own: grabbers, lift, live gap
        // animation and edge auto-scroll. The Edit button matters because each row's
        // Toggle fills the row and swallows the long-press, so without an explicit
        // edit mode there is neither an affordance nor anywhere reliable to grab.
        List {
            switch section {
            case .todayCards:
                dashboardCardsSection
            case .navigation:
                sidebarSectionsSection
            case .food:
                foodTabsSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(HubTheme.canvas)
        .toolbar {
            if section.supportsReordering {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private var sidebarSectionsSection: some View {
        layoutSection(
            description: "Today stays fixed. These sections can be hidden or reordered, and Settings moves into More when space is tight.",
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
            moveBy: moveSidebarModule,
            onMove: moveSidebarModules
        )
    }

    private var foodTabsSection: some View {
        layoutSection(
            description: "Weekly meals stays inside Food. Snacks and Recipes can be hidden.",
            items: HubModules.foodModules,
            isEnabled: { modules.isEnabled($0) },
            label: { $0.label },
            systemImage: { $0.systemImage },
            toggle: { module, enabled in
                let next = modules.updating(module, enabled: enabled)
                updateModules(next)
            },
            moveBy: nil,
            onMove: nil
        )
    }

    @ViewBuilder
    private var dashboardCardsSection: some View {
        Section {
            Picker("Device", selection: $editingTarget) {
                ForEach(DashboardLayoutTarget.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }

        Section {
            // Weather is header chrome now, like the clock, so it isn't a card to
            // configure. Filtered rather than removed from the model so existing
            // stored orders still decode.
            ForEach(Array(layoutCards.enumerated()), id: \.element) { index, card in
                DashboardCardLayoutOptionRow(
                    title: card.label,
                    systemImage: card.systemImage,
                    isOn: Binding(
                        get: { modules.dashboardCards[card, default: true] },
                        set: { enabled in
                            let next = modules.updatingDashboardCard(card, enabled: enabled)
                            updateModules(next)
                        }
                    ),
                    size: Binding(
                        get: {
                            let size = modules.dashboardCardSize(card, for: editingTarget)
                            return size == .compact ? .standard : size
                        },
                        set: { size in
                            let next = modules.updatingDashboardCardSize(card, size: size, for: editingTarget)
                            updateModules(next)
                        }
                    ),
                    canMoveUp: index > 0,
                    canMoveDown: index < layoutCards.count - 1,
                    moveUp: { moveDashboardCard(card, by: -1) },
                    moveDown: { moveDashboardCard(card, by: 1) }
                )
                .listRowBackground(HubTheme.tile)
            }
            .onMove(perform: moveDashboardCards)
        } header: {
            Text("Choose what appears in Today, arrange the order, and set each card’s size for \(editingTarget.label). Tap Edit to reorder.")
                .font(.caption)
                .foregroundStyle(HubTheme.muted)
                .textCase(nil)
        }

        defaultLayoutSection
    }

    // MARK: Saved default

    private var currentLayoutIsSavedDefault: Bool {
        savedDefault?.matches(modules, target: editingTarget) == true
    }

    /// "Reset layout" goes back to the app's arrangement. This keeps the family's own: save the cards
    /// the way you like them, then restore that when they get moved around too much.
    private var defaultLayoutSection: some View {
        Section {
            Button {
                saveCurrentAsDefault()
            } label: {
                Label("Set as Default", systemImage: "square.and.arrow.down")
            }
            .disabled(currentLayoutIsSavedDefault)

            Button {
                confirmingRestoreDefault = true
            } label: {
                Label("Restore Default", systemImage: "arrow.uturn.backward")
            }
            .disabled(savedDefault == nil || currentLayoutIsSavedDefault || isSaving)
            .confirmationDialog(
                "Restore your default Today layout?",
                isPresented: $confirmingRestoreDefault,
                titleVisibility: .visible
            ) {
                Button("Restore Default") { restoreSavedDefault() }
            } message: {
                Text("The Today cards for \(editingTarget.label) go back to how you saved them. Which cards are switched on is shared, so that changes on your other devices too.")
            }
        } header: {
            Text("Default layout")
                .textCase(nil)
        } footer: {
            Text(defaultLayoutFooter)
        }
        .listRowBackground(HubTheme.tile)
    }

    private var defaultLayoutFooter: String {
        if savedDefault == nil {
            return "Arrange the cards how you like them, then tap Set as Default. Restore Default brings that arrangement back for \(editingTarget.label) whenever it gets messy."
        }
        if currentLayoutIsSavedDefault {
            return "This is your default layout for \(editingTarget.label). It is saved on this device."
        }
        return "Set as Default replaces your saved layout for \(editingTarget.label) with what you have now. Restore Default brings the saved one back."
    }

    private func loadSavedDefault() {
        guard let userId = appState.currentUser?.id else {
            savedDefault = nil
            return
        }
        savedDefault = TodayLayoutDefaultStore().load(userId: userId, target: editingTarget)
    }

    private func saveCurrentAsDefault() {
        guard let userId = appState.currentUser?.id else { return }
        let layout = TodayLayoutDefault.capture(from: modules, target: editingTarget)
        TodayLayoutDefaultStore().save(layout, userId: userId, target: editingTarget)
        savedDefault = layout
    }

    private func restoreSavedDefault() {
        guard let savedDefault else { return }
        updateModules(savedDefault.applied(to: modules, target: editingTarget))
    }

    private func layoutSection<Item: Hashable & RawRepresentable>(
        description: String,
        items: [Item],
        isEnabled: @escaping (Item) -> Bool,
        label: @escaping (Item) -> String,
        systemImage: @escaping (Item) -> String,
        toggle: @escaping (Item, Bool) -> Void,
        moveBy: ((Item, Int) -> Void)?,
        onMove: ((IndexSet, Int) -> Void)?
    ) -> some View where Item.RawValue == String {
        Section {
            let rows = ForEach(Array(items.enumerated()), id: \.element) { index, item in
                LayoutOptionRow(
                    title: label(item),
                    systemImage: systemImage(item),
                    isOn: Binding(
                        get: { isEnabled(item) },
                        set: { toggle(item, $0) }
                    ),
                    canMoveUp: moveBy != nil && index > 0,
                    canMoveDown: moveBy != nil && index < items.count - 1,
                    moveUp: { moveBy?(item, -1) },
                    moveDown: { moveBy?(item, 1) }
                )
                .listRowBackground(HubTheme.tile)
            }

            // Food tabs have a fixed order, so they simply get no move action.
            if let onMove {
                rows.onMove(perform: onMove)
            } else {
                rows
            }
        } header: {
            Text(onMove == nil ? description : "\(description) Tap Edit to reorder.")
                .font(.caption)
                .foregroundStyle(HubTheme.muted)
                .textCase(nil)
        }
    }

    // The List calls these once, after the drop. It owns the interactive animation,
    // so there is nothing to apply mid-gesture and nothing to clean up if the drag
    // is abandoned — the whole class of stuck-state bugs goes away with it.
    private func moveSidebarModules(from source: IndexSet, to destination: Int) {
        var next = modules
        next.sidebarOrder.move(fromOffsets: source, toOffset: destination)
        guard next != modules else { return }
        updateModules(next)
    }

    /// Cards the Layout screen lists, for whichever device is currently being edited.
    /// Weather is excluded because it renders in the header rather than the grid.
    private var layoutCards: [DashboardCardId] {
        modules.dashboardOrder(for: editingTarget).filter { $0 != .weather }
    }

    /// Rebuilds the stored order for `editingTarget` from a reordered visible list. The
    /// move offsets index `layoutCards`, not the stored order, so they can't be applied
    /// directly — the hidden entries are pinned to the front instead.
    private func applyingLayoutOrder(_ visible: [DashboardCardId]) -> HubModules {
        var next = modules
        let order = modules.dashboardOrder(for: editingTarget).filter { $0 == .weather } + visible
        switch editingTarget {
        case .phone: next.dashboardOrderPhone = order
        case .tablet: next.dashboardOrderTablet = order
        }
        return next
    }

    private func moveDashboardCards(from source: IndexSet, to destination: Int) {
        var visible = layoutCards
        visible.move(fromOffsets: source, toOffset: destination)
        let next = applyingLayoutOrder(visible)
        guard next != modules else { return }
        updateModules(next)
    }

    private func moveSidebarModule(_ module: HubModuleId, by offset: Int) {
        let next = modules.movingSidebarModule(module, by: offset)
        guard next != modules else { return }
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        updateModules(next)
    }

    /// Accessibility move. Operates on the visible list so a step never lands on the
    /// hidden Weather entry and appears to do nothing.
    private func moveDashboardCard(_ card: DashboardCardId, by offset: Int) {
        var visible = layoutCards
        guard let from = visible.firstIndex(of: card) else { return }
        let to = from + offset
        guard visible.indices.contains(to) else { return }
        visible.swapAt(from, to)
        let next = applyingLayoutOrder(visible)
        guard next != modules else { return }
        withAnimation(.snappy(duration: 0.22)) {
            modules = next
        }
        updateModules(next)
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

private enum LayoutSettingsSection: String, Hashable, Identifiable {
    case todayCards
    case navigation
    case food

    var id: String { rawValue }

    /// Food tabs have a fixed order, so that page gets no Edit button.
    var supportsReordering: Bool {
        switch self {
        case .todayCards, .navigation: true
        case .food: false
        }
    }

    var title: String {
        switch self {
        case .todayCards: "Today Cards"
        case .navigation: "Navigation"
        case .food: "Food"
        }
    }

    var description: String {
        switch self {
        case .todayCards: "Choose cards, order, and size."
        case .navigation: "Choose sidebar sections and order."
        case .food: "Choose optional Food tabs."
        }
    }

    var systemImage: String {
        switch self {
        case .todayCards: "rectangle.3.group.fill"
        case .navigation: "sidebar.left"
        case .food: "fork.knife"
        }
    }

    func summary(_ modules: HubModules) -> String {
        switch self {
        case .todayCards:
            // Enabled cards are the same set on every device; only their order and
            // size differ per target.
            let enabledCount = DashboardCardId.allCases
                .filter { $0 != .weather && modules.isDashboardCardEnabled($0) }
                .count
            return "\(enabledCount)"
        case .navigation:
            let enabledCount = modules.sidebarOrder.filter { modules.isEnabled($0) }.count
            return "\(enabledCount)"
        case .food:
            let enabledCount = HubModules.foodModules.filter { modules.isEnabled($0) }.count
            return "\(enabledCount)/\(HubModules.foodModules.count)"
        }
    }
}

private struct LayoutOptionRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var canMoveUp = false
    var canMoveDown = false
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(HubTheme.accentText)
                .frame(width: 30, height: 30)
                .background(HubTheme.sageSoft)
                .clipShape(Circle())

            Toggle(title, isOn: $isOn)
                .font(.subheadline.weight(.semibold))
        }
        // The List supplies the row background, lift, and drop animation.
        // Reorder stays reachable without a drag for VoiceOver and Switch Control.
        .accessibilityAction(named: Text("Move \(title) up")) { if canMoveUp { moveUp?() } }
        .accessibilityAction(named: Text("Move \(title) down")) { if canMoveDown { moveDown?() } }
    }
}

private struct DashboardCardLayoutOptionRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    @Binding var size: DashboardCardSize
    var canMoveUp = false
    var canMoveDown = false
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(HubTheme.accentText)
                .frame(width: 30, height: 30)
                .background(HubTheme.sageSoft)
                .clipShape(Circle())

            Toggle(title, isOn: $isOn)
                .font(.subheadline.weight(.semibold))

            sizeMenu
        }
        // The List supplies the row background, lift, and drop animation.
        // Reorder stays reachable without a drag for VoiceOver and Switch Control.
        .accessibilityAction(named: Text("Move \(title) up")) { if canMoveUp { moveUp?() } }
        .accessibilityAction(named: Text("Move \(title) down")) { if canMoveDown { moveDown?() } }
    }

    private var sizeMenu: some View {
        Menu {
            ForEach(DashboardCardSize.layoutOptions) { option in
                Button {
                    size = option
                } label: {
                    if size == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(size.label)
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(HubTheme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            // Row background is now HubTheme.tile, so the capsule needs the quieter
            // fill to stay visible against it.
            .background(HubTheme.tileQuiet)
            .clipShape(Capsule())
        }
        .disabled(!isOn)
        .accessibilityLabel("\(title) card size")
    }
}
