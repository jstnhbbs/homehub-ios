import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    /// Branding size, kept at 44pt but scaled against .largeTitle for Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var brandSize: CGFloat = 44

    enum AuthMode {
        case signIn, signUp
    }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Beacon")
                    .font(.system(size: brandSize, weight: .bold, design: .rounded))
                Text("Your family dashboard")
                    .font(.title3)
                    .foregroundStyle(HubTheme.muted)
            }

            Picker("Mode", selection: $mode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Create Account").tag(AuthMode.signUp)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            VStack(spacing: 14) {
                if mode == .signUp {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                }
                // The account field is an email, but Password AutoFill keys off
                // `.username` to pair it with the password; `.emailAddress` only
                // selects the keyboard.
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                // `.newPassword` is what prompts iOS to offer a generated strong
                // password when creating an account; `.password` fills an existing one.
                SecureField("Password (min 10 characters)", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 420)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }

            Button(mode == .signIn ? "Sign In" : "Create Account") {
                Task { await submit() }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(appState.auth.isLoading)
        }
        .padding(40)
    }

    private func submit() async {
        errorMessage = nil
        do {
            if mode == .signIn {
                try await appState.auth.signIn(email: email, password: password)
            } else {
                try await appState.auth.signUp(name: name, email: email, password: password)
            }
            await appState.refreshHousehold()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
