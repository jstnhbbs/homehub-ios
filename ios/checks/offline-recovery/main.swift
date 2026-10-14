import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

// Every request is intercepted, including retries. Nothing leaves this process.
final class OfflineServer: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var failure: URLError.Code?
    nonisolated(unsafe) private static var count = 0
    static func configure(_ code: URLError.Code?) {
        lock.withLock { failure = code; count = 0 }
    }
    static var requests: Int { lock.withLock { count } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let code = Self.lock.withLock { Self.count += 1; return Self.failure }
        if let code {
            client?.urlProtocol(self, didFailWithError: URLError(code))
        } else {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: [:])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

struct DraftInput: Encodable { let title: String }

@MainActor
func run() async {
    let base = URL(string: "https://offline-tests.invalid")!
    let credentials = SessionCredentials(baseURL: base, store: InMemorySecretStore())
    let response = HTTPURLResponse(url: base, statusCode: 200, httpVersion: nil,
        headerFields: ["Set-Cookie": "better-auth.session_token=TEST.sig; Path=/"])!
    credentials.absorb(response, from: base, generation: credentials.sessionGeneration)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [OfflineServer.self]
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let client = APIClient(baseURL: base, session: session, credentials: credentials)

    for code in [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut] {
        OfflineServer.configure(code)
        let editor = EditorSession()
        editor.updateChanges(true)
        let draft = "Keep the family draft"
        var notice: String?
        check("\(code.rawValue): save starts", editor.beginOperation())
        do {
            defer { editor.endOperation() }
            try await client.requestVoid("/api/mobile/v1/notes", body: DraftInput(title: draft))
            check("\(code.rawValue): request must fail", false)
        } catch { notice = error.userFacingMessage }
        check("\(code.rawValue): failure has visible feedback", notice?.isEmpty == false)
        check("\(code.rawValue): failure preserves dirty draft and releases save", editor.hasChanges && !editor.isBusy)
        check("\(code.rawValue): connectivity failure keeps sign-in", credentials.hasSession)
        check("\(code.rawValue): no automatic duplicate write", OfflineServer.requests == 1)
        check("\(code.rawValue): Cancel still confirms retained edits", !editor.requestDismissal() && editor.confirmDiscard)
        OfflineServer.configure(nil)
        check("\(code.rawValue): retry allowed after reconnect", editor.beginOperation())
        do {
            defer { editor.endOperation() }
            try await client.requestVoid("/api/mobile/v1/notes", body: DraftInput(title: draft))
            editor.updateChanges(false)
        } catch { check("reconnected retry succeeds", false) }
        check("\(code.rawValue): successful retry can dismiss", editor.requestDismissal() && !editor.preventsInteractiveDismissal)
        check("\(code.rawValue): reconnect sends exactly one retry", OfflineServer.requests == 1)
    }

    let composer = NoteComposer()
    composer.draft = "  Offline note  "
    OfflineServer.configure(.notConnectedToInternet)
    do {
        try await composer.submit { title in
            try await client.requestVoid("/api/mobile/v1/notes", body: DraftInput(title: title))
        }
        check("offline note must fail", false)
    } catch {
        check("offline note retains its text", composer.draft == "  Offline note  " && composer.canSubmit)
    }
    OfflineServer.configure(nil)
    do {
        let saved = try await composer.submit { title in
            try await client.requestVoid("/api/mobile/v1/notes", body: DraftInput(title: title))
        }
        check("reconnected note clears only on success", saved && composer.draft.isEmpty && !composer.isSaving)
    } catch { check("reconnected note succeeds", false) }
    check("cancelled requests do not show spurious errors", URLError(.cancelled).userFacingMessage == nil)
    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
