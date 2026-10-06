import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: OnboardingMode = .create
    @State private var householdName = ""
    @State private var ownerLastName = ""
    @State private var childName = ""
    @State private var inviteCode = ""
    @State private var guestInviteCode = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    /// Welcome heading, kept at 36pt but scaled against .largeTitle for Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var welcomeSize: CGFloat = 36

    enum OnboardingMode: String, CaseIterable, Identifiable {
        case create, join, guest
        var id: String { rawValue }
        var label: String {
            switch self {
            case .create: "Create Household"
            case .join: "Join as Parent"
            case .guest: "Join as Guest"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Beacon")
                .font(.system(size: welcomeSize, weight: .bold, design: .rounded))
            Text("Create a household or join one with an invite code.")
                .foregroundStyle(HubTheme.muted)

            Picker("Onboarding", selection: $mode) {
                ForEach(OnboardingMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)

            Group {
                switch mode {
                case .create:
                    TextField("Household name", text: $householdName)
                    TextField("Your last name", text: $ownerLastName)
                        .textContentType(.familyName)
                    TextField("First child name (optional)", text: $childName)
                case .join:
                    TextField("Parent invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                case .guest:
                    TextField("Guest invite code", text: $guestInviteCode)
                        .textInputAutocapitalization(.characters)
                }
            }
            .textFieldStyle(HubFieldStyle())
            .frame(maxWidth: 420)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote.weight(.semibold))
            }

            Button("Continue") {
                Task { await submit() }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSubmitting || !canSubmit)
        }
        .padding(40)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            switch mode {
            case .create:
                _ = try await appState.api.createHousehold(
                    CreateHouseholdRequest(
                        name: householdName,
                        ownerLastName: ownerLastName,
                        childName: childName.isEmpty ? nil : childName,
                        timezone: TimeZone.current.identifier
                    )
                )
            case .join:
                _ = try await appState.api.joinHousehold(
                    JoinHouseholdRequest(inviteCode: inviteCode.uppercased())
                )
            case .guest:
                _ = try await appState.api.joinHouseholdAsGuest(
                    JoinGuestHouseholdRequest(guestInviteCode: guestInviteCode.uppercased())
                )
            }
            await appState.refreshHousehold()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .create:
            !householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !ownerLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .join:
            !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .guest:
            !guestInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
