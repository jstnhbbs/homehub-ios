import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: APIClient

    init(baseURL: URL, client: APIClient? = nil) {
        self.client = client ?? APIClient(baseURL: baseURL)
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    /// What asking the server about the saved session found out.
    enum SessionCheck: Sendable {
        /// The server knows the session; `currentUser` is up to date.
        case signedIn
        /// The server answered and there is no session (it expired, or it was ended elsewhere).
        case signedOut
        /// No answer: no connection, a timeout, or a server error. This says nothing about the
        /// session, so it must not sign anyone out.
        case unreachable
    }

    /// Asks the server whether the saved session is still good. Only a clear "no session" signs the
    /// person out. This used to treat every failure that way, so opening the app with no
    /// connection showed the sign-in screen and threw away the offline copy.
    ///
    /// It does not touch `isLoading`, which the root view reads to cover the screen with a spinner;
    /// the check often runs behind the cached screens.
    @discardableResult
    func restoreSession() async -> SessionCheck {
        do {
            let response: SessionResponse? = try await client.request("/api/auth/get-session", authorized: false)
            guard let user = response?.user else {
                currentUser = nil
                return .signedOut
            }
            currentUser = user
            return .signedIn
        } catch {
            return .unreachable
        }
    }

    /// Shows the person who was signed in when the app last ran, until the server confirms.
    func adoptSavedUser(_ user: User) {
        currentUser = user
    }

    /// Ends the session on this device without asking the server, for when the server has already
    /// refused it.
    func endSessionLocally() {
        client.clearCookies()
        currentUser = nil
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let body = SignInRequest(email: email, password: password)
        // A cookie left from an earlier session makes the sign-in service demand an Origin check that
        // a fresh sign-in does not need.
        client.clearCookies()
        let response: AuthEnvelope = try await client.request(
            "/api/auth/sign-in/email",
            method: "POST",
            body: body,
            authorized: false
        )
        currentUser = response.user
    }

    func signUp(name: String, email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let body = SignUpRequest(name: name, email: email, password: password)
        client.clearCookies()
        let response: AuthEnvelope = try await client.request(
            "/api/auth/sign-up/email",
            method: "POST",
            body: body,
            authorized: false
        )
        currentUser = response.user
    }

    /// Emails a fresh confirmation link. The link opens the page on the website that says the address
    /// is confirmed; the app notices the next time it comes to the front (`AppState.refreshSession`).
    func sendVerificationEmail(to email: String) async throws {
        try await client.requestVoid(
            "/api/auth/send-verification-email",
            method: "POST",
            body: SendVerificationRequest(email: email, callbackURL: "/email-verified")
        )
    }

    /// Ends the session on the server (so the cookie stops working everywhere), then forgets it here
    /// whether or not the server could be reached.
    func signOut() async {
        // The sign-in service answers a POST with no JSON body and content type "Unsupported Media
        // Type", so an empty object is sent.
        _ = try? await client.requestVoid("/api/auth/sign-out", method: "POST", body: EmptyJSONBody())
        client.clearCookies()
        currentUser = nil
    }
}

private struct EmptyJSONBody: Encodable {}

private struct SendVerificationRequest: Encodable {
    let email: String
    let callbackURL: String
}

private struct SignInRequest: Encodable {
    let email: String
    let password: String
}

private struct SignUpRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

private struct SessionResponse: Decodable {
    let user: User?
    let session: SessionToken?
}

private struct AuthEnvelope: Decodable {
    let user: User?
    let session: SessionToken?
    let token: String?
}
