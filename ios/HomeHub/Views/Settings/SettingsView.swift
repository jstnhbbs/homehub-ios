import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfilesViewModel()
    @StateObject private var membersViewModel = HouseholdMembersViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))

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

                    if let household = appState.household {
                        householdCard(household)
                    }

                    if appState.canManageHousehold {
                        membersSection
                    }

                    profilesSection

                    if appState.canManageHousehold {
                        CalendarSettingsView()
                    }

                    HubCard {
                        ThemeSettingView()
                    }

                    Button("Sign Out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.canManage {
                sidePanel
                    .frame(width: 360)
            }
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
        .refreshable {
            await viewModel.load()
            await membersViewModel.load()
        }
    }

    @ViewBuilder
    private var sidePanel: some View {
        if viewModel.showAddForm {
            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Add family member", systemImage: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HubTheme.sage)
                    ProfileFormView(
                        mode: .manage,
                        timezone: viewModel.timezone,
                        submitLabel: "Add member"
                    ) { input in
                        await viewModel.addProfile(input)
                    }
                    Button("Cancel") { viewModel.showAddForm = false }
                        .buttonStyle(.bordered)
                }
            }
        } else if let profile = viewModel.selectedProfile {
            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Edit \(profile.name)", systemImage: "pencil")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HubTheme.sage)
                    ProfilePhotoUploadView(profile: profile) {
                        await viewModel.load()
                        await appState.refreshDashboard()
                    }
                    ProfileFormView(
                        profile: profile,
                        mode: .manage,
                        timezone: viewModel.timezone,
                        submitLabel: "Save changes"
                    ) { input in
                        await viewModel.updateProfile(id: profile.id, input: input)
                    }
                }
            }
        } else {
            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Family profiles")
                        .font(.headline)
                    Text("Select a family member to edit, or add someone new.")
                        .foregroundStyle(HubTheme.muted)
                    Button("Add family member") {
                        viewModel.selectedProfileId = nil
                        viewModel.showAddForm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HubTheme.sage)
                }
            }
        }
    }

    private func applyPendingProfileEdit() {
        guard appState.selectedDestination == .settings,
              let profileId = appState.pendingProfileEditId else { return }
        viewModel.showAddForm = false
        viewModel.selectedProfileId = profileId
        appState.pendingProfileEditId = nil
    }

    private func householdCard(_ household: Household) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Household")
                    .font(.headline)
                LabeledContent("Name", value: household.name)
                LabeledContent("Timezone", value: household.timezone)
                LabeledContent("Parent invite", value: household.inviteCode)
                LabeledContent("Guest invite", value: household.guestInviteCode)
                LabeledContent("Your role", value: HouseholdRoles.roleLabel(household.role))
            }
        }
    }

    private var membersSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Household members")
                    .font(.headline)
                Text("Parents manage the hub. Guests can be removed at any time.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                if membersViewModel.isLoading && membersViewModel.members.isEmpty {
                    ProgressView()
                } else if membersViewModel.members.isEmpty {
                    Text("No members found.")
                        .foregroundStyle(HubTheme.muted)
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
                            Text(HouseholdRoles.roleLabel(member.role))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(HubTheme.sageSoft)
                                .clipShape(Capsule())
                            if member.role == .guest {
                                Button("Remove", role: .destructive) {
                                    Task { await membersViewModel.removeGuest(userId: member.userId) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(membersViewModel.isWorking)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var profilesSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Family profiles")
                        .font(.headline)
                    Spacer()
                    if viewModel.canManage {
                        Button("Add") {
                            viewModel.showAddForm = true
                            viewModel.selectedProfileId = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if viewModel.isLoading && viewModel.profiles.isEmpty {
                    ProgressView()
                } else if viewModel.profiles.isEmpty {
                    Text("No profiles yet.")
                        .foregroundStyle(HubTheme.muted)
                } else {
                    profileGroup(title: "Adults", profiles: viewModel.adultProfiles)
                    profileGroup(title: "Children", profiles: viewModel.childProfiles)
                }
            }
        }
    }

    private func profileGroup(title: String, profiles: [Profile]) -> some View {
        Group {
            if !profiles.isEmpty {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .padding(.top, 4)
                ForEach(profiles) { profile in
                    Button {
                        viewModel.showAddForm = false
                        viewModel.selectedProfileId = profile.id
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
                                        Text(birthday)
                                    }
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                            }
                            Spacer()
                            if viewModel.selectedProfileId == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HubTheme.sage)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
