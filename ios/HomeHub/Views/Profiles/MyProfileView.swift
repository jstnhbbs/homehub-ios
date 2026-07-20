import SwiftUI

struct MyProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyProfileViewModel()

    @State private var name = ""
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                if let success = viewModel.successMessage {
                    Text(success).font(.footnote).foregroundStyle(HubTheme.sage)
                }

                if viewModel.isLoading && viewModel.account == nil {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                } else                 if let account = viewModel.account {
                    accountSection(account)
                    if account.profile != nil {
                        familyProfileSection
                    }
                }

                HubCard {
                    ThemeSettingView()
                }

                Button("Sign Out", role: .destructive) {
                    Task { await appState.signOut() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: 720, alignment: .leading)
        }
        .onAppear {
            viewModel.bind(to: appState)
            populateFields()
            appState.pendingProfileEditId = nil
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.account?.user.id) { _, _ in populateFields() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your info")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(HubTheme.sage)
            Text("Profile")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
        }
    }

    private func accountSection(_ account: AccountData) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ProfileAvatarView(
                        name: account.user.name,
                        avatar: account.profile?.avatar,
                        color: account.profile?.color ?? "#6689a3",
                        size: 72
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.user.name)
                            .font(.title3.weight(.semibold))
                        Text(account.user.email)
                            .font(.subheadline)
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                FormField(label: "Display name") {
                    TextField("Your name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                Button("Save name") {
                    Task { _ = await viewModel.updateName(name) }
                }
                .buttonStyle(.borderedProminent)
                .tint(HubTheme.sage)
                .disabled(viewModel.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider()

                FormField(label: "Email") {
                    Text(account.user.email)
                        .font(.subheadline)
                        .foregroundStyle(HubTheme.muted)
                }
                FormField(label: "New email") {
                    TextField("new-email@example.com", text: $newEmail)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                Button("Update email") {
                    Task { _ = await viewModel.changeEmail(newEmail) }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking || newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider()

                FormField(label: "Current password") {
                    SecureField("Current password", text: $currentPassword)
                        .textFieldStyle(.roundedBorder)
                }
                FormField(label: "New password") {
                    SecureField("At least 10 characters", text: $newPassword)
                        .textFieldStyle(.roundedBorder)
                }
                FormField(label: "Confirm new password") {
                    SecureField("Repeat new password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                Button("Change password") {
                    Task {
                        guard newPassword == confirmPassword else {
                            viewModel.errorMessage = "New passwords do not match."
                            return
                        }
                        guard newPassword.count >= 10 else {
                            viewModel.errorMessage = "Password must be at least 10 characters."
                            return
                        }
                        let ok = await viewModel.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword
                        )
                        if ok {
                            currentPassword = ""
                            newPassword = ""
                            confirmPassword = ""
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isWorking || currentPassword.isEmpty || newPassword.isEmpty)
            }
        }
    }

    private var familyProfileSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Family profile")
                    .font(.headline)
                Text("This is how you appear on the family dashboard and calendar.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)

                if let profile = viewModel.account?.profile {
                    ProfilePhotoUploadView(profile: profile) {
                        await viewModel.load()
                        await appState.refreshDashboard()
                    }
                }

                ProfileFormView(
                    profile: viewModel.account?.profile,
                    mode: .selfEdit,
                    timezone: viewModel.timezone,
                    birthdayPickerStyle: .graphical,
                    includeName: false,
                    submitLabel: "Save profile",
                    accountName: viewModel.account?.user.name
                ) { input in
                    await viewModel.updateProfile(input)
                }
            }
        }
    }

    private func populateFields() {
        guard let account = viewModel.account else { return }
        name = account.user.name
        newEmail = account.user.email
    }
}
