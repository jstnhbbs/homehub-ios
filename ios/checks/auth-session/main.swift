import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)\n     got:      \(actual)\n     expected: \(expected)") }
}

// MARK: A stand-in server

/// Answers every request from `StubServer.handler` and remembers what it was sent.
final class StubServer: URLProtocol, @unchecked Sendable {
    typealias Reply = (status: Int, body: String, headers: [String: String])
    nonisolated(unsafe) static var handler: ((URLRequest) -> Result<Reply, Error>)?
    nonisolated(unsafe) static var seen: [URLRequest] = []
    nonisolated(unsafe) static var lastBody: Data?
    nonisolated(unsafe) static var responseDelay: TimeInterval = 0

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
        let reply = Self.handler?(request) ?? .failure(URLError(.notConnectedToInternet))
        if Self.responseDelay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.responseDelay) {
                self.deliver(reply)
            }
        } else {
            deliver(reply)
        }
    }

    private func deliver(_ result: Result<Reply, Error>) {
        switch result {
        case .success(let reply):
            var headers = reply.headers
            headers["Content-Type"] = "application/json"
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

let base = URL(string: "http://localhost:3000")!
let userJSON = #"{"user":{"id":"u1","name":"Pat","email":"pat@example.com","emailVerified":false,"image":null},"session":{"id":"s","token":"t","expiresAt":"2026-11-01T00:00:00.000Z","userId":"u1"}}"#
let setSession = ["Set-Cookie": "better-auth.session_token=TOKEN123.sig; Max-Age=2592000; Path=/; HttpOnly; SameSite=Lax"]
let clearSession = ["Set-Cookie": "better-auth.session_token=; Max-Age=0; Path=/; HttpOnly; SameSite=Lax"]

func respond(_ status: Int, _ body: String, headers: [String: String] = [:]) {
    StubServer.handler = { _ in .success((status, body, headers)) }
}

func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubServer.self]
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    return URLSession(configuration: configuration)
}

/// An app with its own empty Keychain stand-in, as a fresh launch would have.
@MainActor
func makeApp(store: SecretStore = InMemorySecretStore()) -> (auth: AuthService, credentials: SessionCredentials, client: APIClient, store: SecretStore) {
    let credentials = SessionCredentials(baseURL: base, store: store)
    let client = APIClient(baseURL: base, session: makeSession(), credentials: credentials)
    return (AuthService(baseURL: base, client: client), credentials, client, store)
}

// MARK: Pure helpers

check("origin with a port", APIClient.origin(of: URL(string: "http://localhost:3000")!) ?? "nil", "http://localhost:3000")
check("origin without a port", APIClient.origin(of: URL(string: "https://hobbshomehub.vercel.app/some/path")!) ?? "nil", "https://hobbshomehub.vercel.app")
check("sign-in service paths", String(APIClient.isAuthPath("/api/auth/sign-out")), "true")
check("Porchlight's own paths", String(APIClient.isAuthPath("/api/mobile/v1/dashboard")), "false")
check("a message from the sign-in service", APIClient.serverErrorMessage(statusCode: 401, data: Data(#"{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}"#.utf8)), "Invalid email or password")
check("an error from Porchlight's own routes", APIClient.serverErrorMessage(statusCode: 400, data: Data(#"{"error":"Nothing to update."}"#.utf8)), "Nothing to update.")
check("a page that is not JSON", APIClient.serverErrorMessage(statusCode: 502, data: Data("<html>bad gateway</html>".utf8)), "Unexpected server response (502).")

@MainActor
func run() async {
    // A delayed response must not restore the user or cookie after the local session ends.
    do {
        let app = makeApp()
        respond(200, userJSON, headers: setSession)
        StubServer.responseDelay = 0.2
        let restore = Task { await app.auth.restoreSession() }
        try? await Task.sleep(for: .milliseconds(50))
        app.auth.endSessionLocally()
        let result = await restore.value
        StubServer.responseDelay = 0
        check("a delayed restore is discarded after sign-out", String(describing: result), "unreachable")
        check("it cannot restore the user", String(app.auth.isSignedIn), "false")
        check("it cannot restore the cookie", String(app.credentials.hasSession), "false")
    }

    // A slower earlier check cannot undo a newer successful session check.
    do {
        let app = makeApp()
        respond(200, "null")
        StubServer.responseDelay = 0.2
        let older = Task { await app.auth.restoreSession() }
        try? await Task.sleep(for: .milliseconds(50))
        StubServer.responseDelay = 0
        respond(200, userJSON)
        _ = await app.auth.restoreSession()
        _ = await older.value
        check("an older null session cannot overwrite a newer check", String(app.auth.isSignedIn), "true")
    }

    // A response already in flight cannot rotate a newly signed-in account's cookie.
    do {
        let app = makeApp()
        respond(200, "{}", headers: setSession)
        StubServer.responseDelay = 0.2
        let older = Task { () -> Bool in
            do {
                let _: [String: String] = try await app.client.request("/api/mobile/v1/dashboard")
                return false
            } catch { return error.isCancellation }
        }
        try? await Task.sleep(for: .milliseconds(50))
        StubServer.responseDelay = 0
        respond(200, userJSON, headers: ["Set-Cookie": "better-auth.session_token=NEW.sig; Path=/"])
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        check("old account data is cancelled", String(await older.value), "true")
        check("old response cannot replace new cookie", app.credentials.cookieHeader(for: base) ?? "none", "better-auth.session_token=NEW.sig")
    }

    // Ending the session also invalidates a sign-in that has not finished yet.
    do {
        let app = makeApp()
        respond(200, userJSON, headers: setSession)
        StubServer.responseDelay = 0.2
        let signIn = Task { try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234") }
        try? await Task.sleep(for: .milliseconds(50))
        app.auth.endSessionLocally()
        await signIn.value
        StubServer.responseDelay = 0
        check("a delayed sign-in cannot undo local sign-out", String(app.auth.isSignedIn), "false")
        check("a delayed sign-in cannot save its cookie", String(app.credentials.hasSession), "false")
        check("cancelled sign-in releases the loading state", String(app.auth.isLoading), "false")
    }

    // A sign-out from the previous account cannot clear a subsequent sign-in.
    do {
        let app = makeApp()
        respond(200, userJSON, headers: setSession)
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        respond(200, "{}", headers: clearSession)
        StubServer.responseDelay = 0.2
        let signOut = Task { await app.auth.signOut() }
        try? await Task.sleep(for: .milliseconds(50))
        StubServer.responseDelay = 0
        respond(200, userJSON, headers: ["Set-Cookie": "better-auth.session_token=NEW.sig; Path=/"])
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        await signOut.value
        check("old sign-out cannot clear a new user", String(app.auth.isSignedIn), "true")
        check("old sign-out cannot clear a new cookie", app.credentials.cookieHeader(for: base) ?? "none", "better-auth.session_token=NEW.sig")
    }

    // MARK: Checking the saved session

    let (auth, _, _, _) = makeApp()

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
    let fresh = makeApp().auth
    fresh.adoptSavedUser(try! JSONDecoder().decode(User.self, from: Data(#"{"id":"u1","name":"Pat","email":"p@e.com","emailVerified":false}"#.utf8)))
    check("a saved user is shown before the check", String(fresh.isSignedIn), "true")
    respond(200, "null")
    _ = await fresh.restoreSession()
    check("and goes when the server says there is no session", String(fresh.isSignedIn), "false")

    // MARK: The session lives in the Keychain, not in cookie storage

    do {
        let app = makeApp()
        StubServer.seen = []
        respond(200, #"{"redirect":false,"token":"t","user":{"id":"u1","name":"Pat","email":"pat@example.com","emailVerified":false}}"#, headers: setSession)
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        check("signing in saves the session cookie", String(app.credentials.hasSession), "true")
        let stored = app.store.read(account: "http://localhost:3000").flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
        check("in the secret store, by name", stored?["better-auth.session_token"] ?? "nil", "TOKEN123.sig")
        check("and the person is signed in", app.auth.currentUser?.email ?? "nil", "pat@example.com")
        check("the sign-in itself carried no cookie", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "none")
        check("sign-in names the origin", StubServer.seen.first?.value(forHTTPHeaderField: "Origin") ?? "nil", "http://localhost:3000")

        // Later requests send it.
        StubServer.seen = []
        respond(200, "{}")
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/dashboard")
        check("later requests send the saved cookie", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "better-auth.session_token=TOKEN123.sig")
        check("mobile routes carry no Origin", StubServer.seen.first?.value(forHTTPHeaderField: "Origin") ?? "none", "none")

        // Downloads and uploads send it too.
        StubServer.seen = []
        _ = try? await app.client.requestData("/api/mobile/v1/household/export")
        check("downloads send it", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "better-auth.session_token=TOKEN123.sig")
        StubServer.seen = []
        let _: [String: String]? = try? await app.client.uploadMultipart("/api/mobile/v1/household/photo", fileData: Data("x".utf8), fileName: "a.jpg", mimeType: "image/jpeg")
        check("uploads send it", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "better-auth.session_token=TOKEN123.sig")

        // It survives the app being closed: a new launch reads it back from the store.
        let relaunched = makeApp(store: app.store)
        check("a new launch finds the saved session", String(relaunched.credentials.hasSession), "true")
        StubServer.seen = []
        respond(200, "{}")
        let _: [String: String]? = try? await relaunched.client.request("/api/mobile/v1/dashboard")
        check("and sends it", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "better-auth.session_token=TOKEN123.sig")

        // Never to another server, even if a request is built for one.
        let other = URL(string: "https://elsewhere.example.com/x")!
        check("the cookie is not offered to another host", app.credentials.cookieHeader(for: other) ?? "none", "none")
        check("it is offered to this one", app.credentials.cookieHeader(for: URL(string: "http://localhost:3000/anything")!) ?? "none", "better-auth.session_token=TOKEN123.sig")

        // A response from another host cannot plant a session.
        let before = app.credentials.cookieHeader(for: base)
        let foreign = HTTPURLResponse(url: other, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": "better-auth.session_token=EVIL; Path=/"])!
        app.credentials.absorb(foreign, from: other)
        check("a cookie from another host is ignored", String(app.credentials.cookieHeader(for: base) == before), "true")

        // MARK: Signing out

        StubServer.seen = []
        respond(200, #"{"success":true}"#, headers: clearSession)
        await app.auth.signOut()
        let signOutRequest = StubServer.seen.first
        check("sign-out sends the saved cookie", signOutRequest?.value(forHTTPHeaderField: "Cookie") ?? "none", "better-auth.session_token=TOKEN123.sig")
        check("sign-out names the server's origin", signOutRequest?.value(forHTTPHeaderField: "Origin") ?? "nil", "http://localhost:3000")
        check("sign-out goes to the sign-in service", signOutRequest?.url?.path ?? "nil", "/api/auth/sign-out")
        check("sign-out says its body is JSON", signOutRequest?.value(forHTTPHeaderField: "Content-Type") ?? "nil", "application/json")
        check("and sends an empty object", String(data: StubServer.lastBody ?? Data(), encoding: .utf8) ?? "nil", "{}")
        check("the session is gone from the store", String(app.store.read(account: "http://localhost:3000") == nil), "true")
        check("and the person is signed out", String(app.auth.isSignedIn), "false")
        StubServer.seen = []
        respond(200, "{}")
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/dashboard")
        check("a later request sends no cookie", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "none")
    }

    // Even when the server cannot be reached, the device forgets the session.
    do {
        let app = makeApp()
        respond(200, userJSON, headers: setSession)
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        check("signed in again", String(app.credentials.hasSession), "true")
        StubServer.handler = { _ in .failure(URLError(.notConnectedToInternet)) }
        await app.auth.signOut()
        check("offline sign-out still signs out here", String(app.auth.isSignedIn), "false")
        check("and forgets the session", String(app.credentials.hasSession) + " " + String(app.store.read(account: "http://localhost:3000") == nil), "false true")
    }

    // Signing in starts with no old session, so the server has no Origin check to apply.
    do {
        let app = makeApp()
        respond(200, "{}", headers: setSession)
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/x")
        check("an old session is held", String(app.credentials.hasSession), "true")
        StubServer.seen = []
        respond(200, #"{"redirect":false,"token":"t","user":{"id":"u1","name":"Pat","email":"pat@example.com","emailVerified":false}}"#, headers: ["Set-Cookie": "better-auth.session_token=NEW.sig; Max-Age=2592000; Path=/"])
        try? await app.auth.signIn(email: "pat@example.com", password: "abcdefghij1234")
        check("sign-in is sent with no old cookie", StubServer.seen.first?.value(forHTTPHeaderField: "Cookie") ?? "none", "none")
        check("and the new session replaces the old", app.credentials.cookieHeader(for: base) ?? "none", "better-auth.session_token=NEW.sig")
    }

    // Asking for another confirmation email.
    do {
        let app = makeApp()
        respond(200, "{}", headers: setSession)
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/x")
        StubServer.seen = []
        respond(200, #"{"status":true}"#)
        try? await app.auth.sendVerificationEmail(to: "pat@example.com")
        let sent = StubServer.seen.first
        check("a confirmation email is asked for from the sign-in service", sent?.url?.path ?? "nil", "/api/auth/send-verification-email")
        check("as a POST", sent?.httpMethod ?? "nil", "POST")
        check("with the server's origin", sent?.value(forHTTPHeaderField: "Origin") ?? "nil", "http://localhost:3000")
        let body = (try? JSONSerialization.jsonObject(with: StubServer.lastBody ?? Data())) as? [String: String]
        check("naming the address", body?["email"] ?? "nil", "pat@example.com")
        check("and the page the link should end on", body?["callbackURL"] ?? "nil", "/email-verified")

        respond(429, #"{"message":"Too many requests. Please try again later."}"#)
        var reason = "no error"
        do { try await app.auth.sendVerificationEmail(to: "pat@example.com") } catch { reason = error.localizedDescription }
        check("too many requests reads as a sentence", reason, "Too many requests. Please try again later.")
    }

    // A wrong password reads as a sentence, not JSON.
    do {
        let app = makeApp()
        respond(401, #"{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}"#)
        var message = "no error"
        do { try await app.auth.signIn(email: "pat@example.com", password: "wrong-password") } catch { message = error.localizedDescription }
        check("a wrong password is a readable message", message, "Invalid email or password")
        check("and saves no session", String(app.credentials.hasSession), "false")
    }

    // The sign-in service can rotate the cookie on any response, and the app keeps up.
    do {
        let app = makeApp()
        respond(200, "{}", headers: setSession)
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/a")
        respond(200, "{}", headers: ["Set-Cookie": "better-auth.session_token=ROTATED.sig; Max-Age=2592000; Path=/"])
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/b")
        check("a refreshed cookie replaces the old one", app.credentials.cookieHeader(for: base) ?? "none", "better-auth.session_token=ROTATED.sig")
        // Several cookies are all kept and sent.
        respond(200, "{}", headers: ["Set-Cookie": "other=1; Path=/"])
        let _: [String: String]? = try? await app.client.request("/api/mobile/v1/c")
        check("more than one cookie is kept", app.credentials.cookieHeader(for: base) ?? "none", "better-auth.session_token=ROTATED.sig; other=1")
    }

    // The production cookie name carries a prefix and is Secure.
    do {
        let secure = URL(string: "https://hobbshomehub.vercel.app")!
        let credentials = SessionCredentials(baseURL: secure, store: InMemorySecretStore())
        let response = HTTPURLResponse(url: secure, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": "__Secure-better-auth.session_token=PROD.sig; Max-Age=2592000; Path=/; HttpOnly; Secure; SameSite=Lax"])!
        credentials.absorb(response, from: secure)
        check("the production cookie is kept under its full name", credentials.cookieHeader(for: secure) ?? "none", "__Secure-better-auth.session_token=PROD.sig")
    }

    // MARK: Moving over from the old cookie storage

    do {
        let suite = UserDefaults(suiteName: "auth-session-check-\(UUID().uuidString)")!
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "auth-session-check-\(UUID().uuidString)")
        let old = HTTPCookie(properties: [.domain: "localhost", .path: "/", .name: "better-auth.session_token", .value: "OLD.sig"])!
        storage.setCookie(old)

        // Someone already signed in: the cookie moves to the store and is removed from the old place.
        let upgrading = SessionCredentials(baseURL: base, store: InMemorySecretStore())
        upgrading.migrateOnFirstLaunch(baseURL: base, defaults: suite, storage: storage)
        check("an existing sign-in moves to the secure store", upgrading.cookieHeader(for: base) ?? "none", "better-auth.session_token=OLD.sig")
        check("and is removed from the cookie storage", String(storage.cookies(for: base)?.count ?? 0), "0")

        // It only happens once.
        let again = SessionCredentials(baseURL: base, store: InMemorySecretStore())
        again.migrateOnFirstLaunch(baseURL: base, defaults: suite, storage: storage)
        check("it does not run a second time", String(again.hasSession), "false")
    }

    do {
        // A fresh install: the Keychain still holds the last install's session, which is cleared.
        let suite = UserDefaults(suiteName: "auth-session-check-\(UUID().uuidString)")!
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "auth-session-check-\(UUID().uuidString)")
        let leftover = InMemorySecretStore()
        leftover.write(try! JSONEncoder().encode(["better-auth.session_token": "LEFTOVER.sig"]), account: "http://localhost:3000")
        let credentials = SessionCredentials(baseURL: base, store: leftover)
        check("the leftover is read at first", String(credentials.hasSession), "true")
        credentials.migrateOnFirstLaunch(baseURL: base, defaults: suite, storage: storage)
        check("a fresh install clears a session left in the Keychain", String(credentials.hasSession) + " " + String(leftover.read(account: "http://localhost:3000") == nil), "false true")
    }

    if failures > 0 {
        print("\(failures) failed")
        exit(1)
    }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
