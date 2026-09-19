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
    @State private var exportDocument: HouseholdExportDocument?
    @State private var isPreparingExport = false
    @State private var showExporter = false

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
            permissionsSummarySection
            statusMessagesSection

            Section {
                settingsRow(.general)
                settingsRow(.family)
            } header: {
                Text("Household")
            }

            Section {
                settingsRow(.appearance)
                settingsRow(.calendar)
                settingsRow(.notifications)
                settingsRow(.layout)
            } header: {
                Text("Beacon")
            }

            Section {
                settingsRow(.faq)
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
        case .appearance:
            appearanceTab
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
                    Task { await appState.signOut() }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "beacon-export-\(DateHelpers.localDateIn(timezone: .current))"
        ) { result in
            if case .failure(let error) = result {
                appState.errorMessage = error.localizedDescription
            }
            exportDocument = nil
        }
        .onAppear {
            if let household = appState.household {
                weekStartsOn = WeekStart.parseWeekStartsOn(household.weekStartsOn)
            }
        }
    }

    private var appearanceTab: some View {
        Form {
            ThemeSettingView()

            Section {
                LabeledContent("Launch Loading", value: "Native spinner")
                LabeledContent("App Icon Picker", value: "This device")
            } header: {
                Text("Icon Behavior")
            } footer: {
                Text("Beacon shows cached app content as soon as possible. Alternate app icons only affect the Home Screen icon after iOS applies the change.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
            appState.errorMessage = error.localizedDescription
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
            FAQItem("How do I use Beacon on more than one device?", "Install Beacon on each device and sign in. Use the same account, or have another parent create an account and join your household with the parent invite code in Settings > Family. Shared household information comes from the same backend on your phone and larger display."),
            FAQItem("What is the difference between an account and a family profile?", "An account is a sign-in for someone using Beacon. A family profile represents a person in your household, including children who do not need their own sign-in. Profiles let you assign routines and chores and keep birthdays together."),
            FAQItem("How do I invite a parent or helper?", "Find the invite codes in Settings > Family. Share the parent code with another parent, or the guest code with a helper. They create an account and join with that code. Treat invite codes as private household information."),
            FAQItem("What can owners, parents, and guests do?", "Owners and parents manage household setup and family information. Guests can use household views without changing global settings. Your role and available permissions appear at the top of Settings.")
        ]),
        FAQSection(title: "Today & Layout", questions: [
            FAQItem("How do I choose and arrange Today cards?", "Open Settings > Layout > Today Cards. Toggle the cards you want to see and use the reorder controls to arrange them. Your card choices and order are saved for your signed-in user."),
            FAQItem("What do Standard and Expanded mean?", "On larger layouts, Standard uses one column and Expanded uses two columns when space allows. Expanded changes width rather than making a whole row taller. On iPhone, cards stay in a single column; the size preference is for larger layouts."),
            FAQItem("Do my layout choices follow me between iPhone and iPad?", "Yes. Layout preferences are saved to your account, so the same user can use them on iPhone and iPad. Another parent has their own layout preferences. Each device adapts the arrangement to its available space."),
            FAQItem("Where are the sections I cannot see in navigation?", "Tap More to see overflow sections. Larger screens show more sections directly when space allows. Open Settings > Layout > Navigation to choose and reorder optional sections; Today stays available.")
        ]),
        FAQSection(title: "Calendars & Reminders", questions: [
            FAQItem("How do I connect my calendar?", "Open Settings > Calendar & Reminders and allow native calendar access. Beacon reads the calendars available in Apple Calendar on that device. Add iCloud, Google, or other accounts to the device's Calendar settings first; you do not sign in to those providers inside Beacon."),
            FAQItem("How do I choose which calendars appear?", "In Settings > Calendar & Reminders, open the calendar selection and choose from the accessible device calendars. Save your selection, or select all calendars. Configure calendar access and selection separately on each device."),
            FAQItem("Why are events different on my phone and iPad?", "Calendars are read locally through Apple Calendar. Check that both devices have the same calendar accounts, that the calendars are syncing in Apple Calendar, and that Beacon has access and the intended calendars selected on each device. Joining the same Beacon household does not share a calendar account."),
            FAQItem("How do I switch between day, week, and month?", "Open Calendar and select Day, Week, or Month. Tap a date in the grid to open Day view, or tap an event to see its details. Use the previous and next controls to move through dates, or Today to return to the current date. Search filters the events in the current calendar range."),
            FAQItem("How do groceries work with Apple Reminders?", "Allow Reminders access in Settings > Calendar & Reminders and choose a list. Beacon uses that device's selected Reminders list. To see the same items elsewhere, share or sync the list through Apple Reminders and select it on each device. Without Reminders access, Beacon uses the household grocery list on the backend; these are separate lists."),
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
            FAQItem("Can I use Beacon offline?", "Beacon can show cached household and Today content when it is available. Shared household edits need a working connection to the backend; do not assume offline edits will be queued and uploaded later. Native calendars and Reminders depend on what is available locally on your device."),
            FAQItem("Why is weather unavailable?", "Weather needs device location access and an available weather service. Allow location access when prompted, check Beacon's permissions in system settings, and make sure the device has a connection. Weather may be unavailable on some devices or environments."),
            FAQItem("Why am I not receiving reminders?", "Open Settings > Notifications in Beacon, allow notifications, and enable the reminders and times you want. Also check the device's notification settings, Focus modes, and Scheduled Summary. Beacon's reminder preferences and notification permission are configured on each device."),
            FAQItem("How do I change colors or light and dark mode?", "Choose a theme color or app icon in Settings > Appearance. Beacon follows your device's system light or dark appearance. Theme and icon choices apply locally to that device.")
        ])
    ]
}

private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
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
        case .family: "Manage members and family profiles."
        case .calendar: "Access, defaults, alerts, and calendars on this device."
        case .notifications: "Configure native reminder times."
        case .layout: "Choose and arrange hub sections."
        case .data: "Check backend status and refresh local data."
        case .faq: "Getting started, everyday use, and troubleshooting."
        case .about: "Version, privacy, and terms."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
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
        layoutRoot
            .onAppear {
                modules = appState.hubModules
            }
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
                            .foregroundStyle(HubTheme.sage)

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
                    updateModules(.defaults)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
                .disabled(isSaving)
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
                    .foregroundStyle(HubTheme.sage)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch section {
                case .todayCards:
                    dashboardCardsGroup
                case .navigation:
                    sidebarSectionsGroup
                case .food:
                    foodTabsGroup
                }
            }
            .padding()
        }
    }

    private var sidebarSectionsGroup: some View {
        layoutGroup(
            title: "Sidebar sections",
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
            moveBefore: reorderSidebarModule,
            moveBy: moveSidebarModule
        )
    }

    private var foodTabsGroup: some View {
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
    }

    private var dashboardCardsGroup: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dashboard cards")
                    .font(.headline)
                Text("Choose what appears in Today, arrange the order, and set each card’s size.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)

                ForEach(Array(modules.dashboardOrder.enumerated()), id: \.element) { index, card in
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
                                let size = modules.dashboardCardSize(card)
                                return size == .compact ? .standard : size
                            },
                            set: { size in
                                let next = modules.updatingDashboardCardSize(card, size: size)
                                updateModules(next)
                            }
                        ),
                        isDragging: draggedLayoutItem == rawValue(card),
                        isDropTarget: dropTargetItem == rawValue(card),
                        canMoveUp: index > 0,
                        canMoveDown: index < modules.dashboardOrder.count - 1,
                        moveUp: { moveDashboardCard(card, by: -1) },
                        moveDown: { moveDashboardCard(card, by: 1) },
                        dragProvider: {
                            draggedLayoutItem = rawValue(card)
                            return NSItemProvider(object: rawValue(card) as NSString)
                        }
                    )
                    .onDrop(
                        of: [UTType.plainText.identifier],
                        delegate: LayoutReorderDropDelegate(
                            targetValue: rawValue(card),
                            draggedValue: $draggedLayoutItem,
                            dropTargetValue: $dropTargetItem,
                            onMoveBefore: { draggedValue, targetValue in
                                guard draggedValue != targetValue,
                                      let draggedCard = modules.dashboardOrder.first(where: { rawValue($0) == draggedValue }),
                                      let targetCard = modules.dashboardOrder.first(where: { rawValue($0) == targetValue }) else {
                                    return
                                }
                                if let next = reorderDashboardCard(draggedCard, before: targetCard) {
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

private enum LayoutSettingsSection: String, Hashable, Identifiable {
    case todayCards
    case navigation
    case food

    var id: String { rawValue }

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
            let enabledCount = modules.dashboardOrder.filter { modules.isDashboardCardEnabled($0) }.count
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

private struct DashboardCardLayoutOptionRow: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    @Binding var size: DashboardCardSize
    var isDragging = false
    var isDropTarget = false
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

            sizeMenu
            dragHandle
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
                Text(sizeLabel)
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(HubTheme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(HubTheme.tile)
            .clipShape(Capsule())
        }
        .disabled(!isOn)
        .accessibilityLabel("\(title) iPad card size")
    }

    private var sizeLabel: String {
        horizontalSizeClass == .compact ? "iPad \(size.label)" : size.label
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
            Text(size.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(HubTheme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 300, alignment: .leading)
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
