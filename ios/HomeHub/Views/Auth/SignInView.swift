import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var appState: AppState

    @State private var mode: AuthMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    enum AuthMode {
        case signIn, signUp
    }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Home Hub")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Your family dashboard for iPad")
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
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password (min 10 characters)", text: $password)
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
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .controlSize(.large)
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
