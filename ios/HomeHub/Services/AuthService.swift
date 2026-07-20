import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client: APIClient

    init(baseURL: URL) {
        self.client = APIClient(baseURL: baseURL)
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SessionResponse = try await client.request("/api/auth/get-session", authorized: false)
            currentUser = response.user
        } catch {
            currentUser = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let body = SignInRequest(email: email, password: password)
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
        let response: AuthEnvelope = try await client.request(
            "/api/auth/sign-up/email",
            method: "POST",
            body: body,
            authorized: false
        )
        currentUser = response.user
    }

    func signOut() async {
        _ = try? await client.requestVoid("/api/auth/sign-out", method: "POST")
        currentUser = nil
    }
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
