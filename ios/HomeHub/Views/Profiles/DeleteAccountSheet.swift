import SwiftUI

struct DeleteAccountSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isDeleting = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your account. It can't be undone.")
                        .font(.subheadline.weight(.semibold))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If you're the only member of your household, the household and everything in it is deleted too: routines, chores, meals, recipes, groceries, notes, and sleep logs.")
                        Text("If other people share your household and you're its only owner, make someone else an owner first in Settings.")
                        Text("Otherwise you simply leave the household and your profile is removed. Everyone else keeps their data.")
                        if appState.canManageHousehold {
                            Text("Want a copy first? Use Settings → General → Export Household Data.")
                        }
                    }
                }

                Section("Confirm with your password") {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text(isDeleting ? "Deleting" : "Delete My Account")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isDeleting || password.isEmpty)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
            .alert("Delete your account?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This is permanent.")
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await appState.api.deleteAccount(password: password)
            dismiss()
            await appState.signOut()
        } catch {
            errorMessage = error.userFacingMessage ?? error.localizedDescription
        }
    }
}
