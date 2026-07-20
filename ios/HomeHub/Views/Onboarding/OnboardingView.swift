import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: OnboardingMode = .create
    @State private var householdName = ""
    @State private var childName = ""
    @State private var inviteCode = ""
    @State private var guestInviteCode = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

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
            Text("Welcome to Home Hub")
                .font(.system(size: 36, weight: .bold, design: .rounded))
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
                    TextField("First child name (optional)", text: $childName)
                case .join:
                    TextField("Parent invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                case .guest:
                    TextField("Guest invite code", text: $guestInviteCode)
                        .textInputAutocapitalization(.characters)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 420)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote.weight(.semibold))
            }

            Button("Continue") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .controlSize(.large)
            .disabled(isSubmitting)
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
}
