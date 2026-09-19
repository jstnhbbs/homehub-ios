import SwiftUI

struct MyProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyProfileViewModel()

    @State private var name = ""
    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showDeleteAccount = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .padding(.horizontal)

            Form {
                statusSection
                if viewModel.isLoading && viewModel.account == nil {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let account = viewModel.account {
                    accountSection(account)
                    if account.profile != nil {
                        familyProfileSection
                    }
                }

                ThemeSettingView()

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                }

                if viewModel.account != nil {
                    Section {
                        Button("Delete Account…", role: .destructive) {
                            showDeleteAccount = true
                        }
                    } footer: {
                        Text("Permanently removes your account. You'll be asked to confirm with your password.")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountSheet()
                    .environmentObject(appState)
            }
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
            Text("Profile")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
        }
    }

    @ViewBuilder
    private var statusSection: some View {
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

    private func accountSection(_ account: AccountData) -> some View {
        Group {
            Section("Account") {
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

                TextField("Display Name", text: $name)
                    .textContentType(.name)

                Button("Save Name") {
                    Task { _ = await viewModel.updateName(name) }
                }
                .disabled(viewModel.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Email") {
                LabeledContent("Current Email", value: account.user.email)
                TextField("New Email", text: $newEmail)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                Button("Update Email") {
                    Task { _ = await viewModel.changeEmail(newEmail) }
                }
                .disabled(viewModel.isWorking || newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Password") {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)

                Button("Change Password") {
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
                .disabled(viewModel.isWorking || currentPassword.isEmpty || newPassword.isEmpty)
            }
        }
    }

    private var familyProfileSection: some View {
        Section {
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
                submitLabel: "Save Profile",
                accountName: viewModel.account?.user.name
            ) { input in
                await viewModel.updateProfile(input)
            }
        } header: {
            Text("Family Profile")
        } footer: {
            Text("This is how you appear on the family dashboard and calendar.")
        }
    }

    private func populateFields() {
        guard let account = viewModel.account else { return }
        name = account.user.name
        newEmail = account.user.email
    }
}
