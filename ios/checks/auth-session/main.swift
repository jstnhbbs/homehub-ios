import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// MARK: A stand-in server

/// Answers every request from `StubServer.handler` and remembers what it was sent.
final class StubServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> Result<(Int, String), Error>)?
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var cookiesHeldWhenSeen: [Int] = []
    nonisolated(unsafe) static var lastBody: Data?

    /// A request's body reaches a URLProtocol as a stream, not as `httpBody`.
    static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.seen.append(request)
        Self.lastBody = Self.readBody(of: request)
        Self.cookiesHeldWhenSeen.append(HTTPCookieStorage.shared.cookies(for: request.url!)?.count ?? 0)
        switch Self.handler?(request) ?? .failure(URLError(.notConnectedToInternet)) {
        case .success(let (status, body)):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

URLProtocol.registerClass(StubServer.self)
let base = URL(string: "http://localhost:3000")!
let userJSON = #"{"user":{"id":"u1","name":"Pat","email":"pat@example.com","emailVerified":false,"image":null},"session":{"id":"s","token":"t","expiresAt":"2026-11-01T00:00:00.000Z","userId":"u1"}}"#

func respond(_ status: Int, _ body: String) { StubServer.handler = { _ in .success((status, body)) } }

// MARK: Pure helpers

check("origin with a port", APIClient.origin(of: URL(string: "http://localhost:3000")!) ?? "nil", "http://localhost:3000")
check("origin without a port", APIClient.origin(of: URL(string: "https://hobbshomehub.vercel.app/some/path")!) ?? "nil", "https://hobbshomehub.vercel.app")
check("sign-in service paths", String(APIClient.isAuthPath("/api/auth/sign-out")), "true")
check("Beacon's own paths", String(APIClient.isAuthPath("/api/mobile/v1/dashboard")), "false")
check("a message from the sign-in service", APIClient.serverErrorMessage(statusCode: 401, data: Data(#"{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}"#.utf8)), "Invalid email or password")
check("an error from Beacon's own routes", APIClient.serverErrorMessage(statusCode: 400, data: Data(#"{"error":"Nothing to update."}"#.utf8)), "Nothing to update.")
check("a page that is not JSON", APIClient.serverErrorMessage(statusCode: 502, data: Data("<html>bad gateway</html>".utf8)), "Unexpected server response (502).")

// MARK: Checking the saved session

@MainActor
func run() async {
    let auth = AuthService(baseURL: base)

    respond(200, "null")
    var result = await auth.restoreSession()
    check("the server says there is no session: signed out", "\(result) \(auth.isSignedIn)", "signedOut false")

    respond(200, userJSON)
    result = await auth.restoreSession()
    check("the server knows the session: signed in", "\(result) \(auth.currentUser?.name ?? "nil")", "signedIn Pat")

    // None of these say anything about the session, so the person stays signed in.
    respond(500, #"{"error":"boom"}"#)
    result = await auth.restoreSession()
    check("a server error does not sign anyone out", "\(result) \(auth.isSignedIn)", "unreachable true")

    StubServer.handler = { _ in .failure(URLError(.notConnectedToInternet)) }
    result = await auth.restoreSession()
    check("no connection does not sign anyone out", "\(result) \(auth.isSignedIn)", "unreachable true")

    StubServer.handler = { _ in .failure(URLError(.timedOut)) }
    result = await auth.restoreSession()
    check("a timeout does not sign anyone out", "\(result) \(auth.isSignedIn)", "unreachable true")

    respond(200, "<html>Sign in to this Wi-Fi network</html>")
    result = await auth.restoreSession()
    check("a Wi-Fi sign-in page does not sign anyone out", "\(result) \(auth.isSignedIn)", "unreachable true")

    // The saved person is shown straight away, and a "no session" answer then takes them away again.
    let fresh = AuthService(baseURL: base)
    fresh.adoptSavedUser(try! JSONDecoder().decode(User.self, from: Data(#"{"id":"u1","name":"Pat","email":"p@e.com","emailVerified":false}"#.utf8)))
    check("a saved user is shown before the check", String(fresh.isSignedIn), "true")
    respond(200, "null")
    _ = await fresh.restoreSession()
    check("and goes when the server says there is no session", String(fresh.isSignedIn), "false")

    // MARK: Origin and cookies

    func setStaleCookie() {
        let cookie = HTTPCookie(properties: [.domain: "localhost", .path: "/", .name: "better-auth.session_token", .value: "stale", .secure: "FALSE"])!
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    // Signing out must reach the server with its cookie and an Origin, or the server refuses it.
    setStaleCookie()
    StubServer.seen = []
    respond(200, #"{"success":true}"#)
    await auth.signOut()
    let signOutRequest = StubServer.seen.first
    let signOutBody = StubServer.lastBody
    check("sign-out names the server's origin", signOutRequest?.value(forHTTPHeaderField: "Origin") ?? "nil", "http://localhost:3000")
    check("sign-out goes to the sign-in service", signOutRequest?.url?.path ?? "nil", "/api/auth/sign-out")
    check("sign-out says its body is JSON", signOutRequest?.value(forHTTPHeaderField: "Content-Type") ?? "nil", "application/json")
    check("and sends an empty object", String(data: signOutBody ?? Data(), encoding: .utf8) ?? "nil", "{}")
    check("the cookie is forgotten afterwards", String(HTTPCookieStorage.shared.cookies(for: base)?.count ?? 0), "0")
    check("and the person is signed out", String(auth.isSignedIn), "false")

    // Even when the server cannot be reached, the device forgets the session.
    setStaleCookie()
    respond(200, userJSON)
    _ = await auth.restoreSession()
    StubServer.handler = { _ in .failure(URLError(.notConnectedToInternet)) }
    await auth.signOut()
    check("offline sign-out still signs out here", String(auth.isSignedIn), "false")
    check("and forgets the cookie", String(HTTPCookieStorage.shared.cookies(for: base)?.count ?? 0), "0")

    // Signing in starts with no old cookie, so the server has no Origin check to apply.
    setStaleCookie()
    StubServer.seen = []
    StubServer.cookiesHeldWhenSeen = []
    respond(200, #"{"redirect":false,"token":"t","user":{"id":"u1","name":"Pat","email":"pat@example.com","emailVerified":false}}"#)
    try? await auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
    check("sign-in is sent with no old cookie held", String(StubServer.cookiesHeldWhenSeen.first ?? -1), "0")
    check("sign-in also names the origin", StubServer.seen.first?.value(forHTTPHeaderField: "Origin") ?? "nil", "http://localhost:3000")
    check("and signs the person in", auth.currentUser?.email ?? "nil", "pat@example.com")

    // A wrong password reads as a sentence, not JSON.
    respond(401, #"{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}"#)
    var message = "no error"
    do { try await auth.signIn(email: "pat@example.com", password: "wrong-password") } catch { message = error.localizedDescription }
    check("a wrong password is a readable message", message, "Invalid email or password")

    // Beacon's own routes get no Origin: they are not behind the sign-in service's check.
    StubServer.seen = []
    respond(200, "{}")
    let api = APIClient(baseURL: base)
    let _: [String: String]? = try? await api.request("/api/mobile/v1/dashboard")
    check("mobile routes carry no Origin", StubServer.seen.first?.value(forHTTPHeaderField: "Origin") ?? "none", "none")

    if failures > 0 {
        print("\(failures) failed")
        exit(1)
    }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
