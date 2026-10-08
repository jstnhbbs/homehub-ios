import SwiftUI

/// The household's two invite codes, with a way to replace either one. A replaced code stops
/// working immediately; people already in the household are not affected.
struct InviteCodesSection: View {
    @EnvironmentObject private var appState: AppState
    let household: Household

    private enum Which: String, Identifiable {
        case parent
        case guest

        var id: String { rawValue }
        var title: String { self == .parent ? "Parent Invite" : "Guest Invite" }
    }

    @State private var confirming: Which?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            codeRow(.parent, code: household.inviteCode)
            codeRow(.guest, code: household.guestInviteCode)
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Invite Codes")
        } footer: {
            Text("Share the parent code with another parent after they create an account. The guest code is for grandparents, nannies, and other helpers. If a code goes to the wrong person, replace it: the old one stops working at once, and people already in the household stay.")
        }
        .confirmationDialog(
            confirming.map { "Replace the \($0.title.lowercased()) code?" } ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { which in
            Button("Replace Code", role: .destructive) {
                Task { await replace(which) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Anyone who has the current code, and hasn't joined yet, will no longer be able to use it.")
        }
    }

    private func codeRow(_ which: Which, code: String) -> some View {
        LabeledContent(which.title) {
            HStack(spacing: 12) {
                Text(code)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                Button {
                    confirming = which
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
                .disabled(isWorking)
                .accessibilityLabel("Replace \(which.title.lowercased()) code")
            }
        }
    }

    private func replace(_ which: Which) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            appState.household = try await appState.api.regenerateInviteCodes(which: which.rawValue)
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }
}
