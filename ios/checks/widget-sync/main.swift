import Foundation

// Real queue, credentials, API client and sync; only HTTP and the intent's error type are stand-ins.
enum WidgetActionFailure: LocalizedError, Equatable {
    case stale, failed, openApp
    var errorDescription: String? { "Widget action failed" }
}
final class Server: URLProtocol, @unchecked Sendable {
    typealias Reply = (status: Int, body: String, headers: [String: String], delay: TimeInterval)
    nonisolated(unsafe) static var handler: (URLRequest) -> Reply = { _ in (200, "{}", [:], 0) }
    private let lock = NSLock()
    private var cancelled = false
    private var work: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let reply = Self.handler(request)
        let work = DispatchWorkItem { [self] in
            lock.withLock {
                guard !cancelled else { return }
                let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        self.work = work
        DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay, execute: work)
    }
    override func stopLoading() { lock.withLock { cancelled = true; work?.cancel() } }
}
var failures = 0
func check(_ label: String, _ value: Bool) {
    if value { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
let serverURL = URL(string: "https://example.com")!
struct Fixture {
    let directory: URL
    let store: WidgetStore
    let queue: WidgetPendingQueue
    let secrets = InMemorySecretStore()
    let credentials: SessionCredentials
    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("widget-sync-\(UUID().uuidString)")
        store = WidgetStore(directory: directory)
        queue = WidgetPendingQueue(directory: directory)
        secrets.write(try! JSONEncoder().encode(["session": "old"]), account: "https://example.com")
        credentials = SessionCredentials(baseURL: serverURL, store: secrets, readOnly: true)
        let snapshot = WidgetSnapshot(userId: "user", householdId: "home", householdName: "Family", timezone: "UTC",
            localDate: "2026-11-02", updatedAt: .now, accentLight: "#57764C", accentDark: "#5F8153", enabledDestinations: [],
            people: [], steps: [], chores: [], events: [], dinner: nil, sleeps: [], notes: [], groceries: [], groceryCount: 0,
            celebrations: [], server: serverURL.absoluteString)
        store.save(snapshot)
    }
    func add(_ id: String) {
        queue.enqueue(.init(id: id, action: "step", itemId: id, userId: "user", householdId: "home", localDate: "2026-11-02", tappedAt: .now))
    }
    func flush(timeout: TimeInterval = 2) async -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Server.self]
        return await WidgetSync.flush(store: store, queue: queue, timeout: timeout, credentials: credentials, configuration: configuration)
    }
    func clean() { try? FileManager.default.removeItem(at: directory) }
}
@main struct Checks {
    static func main() async {
        do {
            let f = Fixture(); defer { f.clean() }; f.add("one")
            Server.handler = { request in
                request.url!.path == "/api/auth/get-session" ? (200, #"{"user":{"id":"user"}}"#, [:], 0) : (200, "{}", [:], 0)
            }
            let result = await f.flush()
            check("a verified account sends and removes its completion", result && f.queue.load().isEmpty)
        }
        do {
            let f = Fixture(); defer { f.clean() }; f.add("one")
            Server.handler = { request in
                request.url!.path == "/api/auth/get-session" ? (200, #"{"user":{"id":"user"}}"#, [:], 0) : (503, "{}", ["Retry-After": "60"], 0)
            }
            let result = await f.flush()
            check("HTTP 503 preserves a queued tap", !result && f.queue.load().count == 1)
            check("the retry is backed off and released", f.queue.load().first?.claimedAt == nil && f.queue.load().first?.retryAfter != nil)
        }
        do {
            let f = Fixture(); defer { f.clean() }; f.add("one")
            Server.handler = { request in
                request.url!.path == "/api/auth/get-session" ? (200, #"{"user":{"id":"user"}}"#, [:], 0) : (200, "{}", [:], 5)
            }
            let start = Date()
            let result = await f.flush(timeout: 0.15)
            check("the deadline cancels the actual request instead of awaiting a detached send", Date().timeIntervalSince(start) < 1)
            check("timed-out work remains durable and is not left claimed", !result && f.queue.load().count == 1 && f.queue.load().first?.claimedAt == nil)
        }
        do {
            let f = Fixture(); defer { f.clean() }; f.add("one")
            Server.handler = { request in
                if request.url!.path == "/api/auth/get-session" { return (200, #"{"user":{"id":"user"}}"#, [:], 0) }
                f.secrets.write(try! JSONEncoder().encode(["session": "new"]), account: "https://example.com")
                f.queue.enqueue(.init(id: "new-account", action: "step", itemId: "new", userId: "new-user", householdId: "new-home", localDate: "2026-11-02", tappedAt: .now))
                var newer = f.store.load()!; newer.userId = "new-user"; newer.householdId = "new-home"; f.store.save(newer, force: true)
                return (401, "{}", [:], 0)
            }
            _ = await f.flush()
            check("a late authorization failure cannot clear the new account's queue", f.queue.load().contains { $0.id == "new-account" })
            check("a late response cannot overwrite the new account's snapshot", f.store.load()?.userId == "new-user")
        }
        do {
            let f = Fixture(); defer { f.clean() }; f.add("one")
            Server.handler = { request in
                if request.url!.path == "/api/auth/get-session" { return (200, #"{"user":{"id":"someone-else"}}"#, [:], 0) }
                check("mismatched identity must not write", false)
                return (200, "{}", [:], 0)
            }
            let result = await f.flush()
            check("a stale snapshot cannot write with another account's credentials", !result && f.queue.load().count == 1)
        }
        if failures > 0 { exit(1) }
        print("all passed")
    }
}
