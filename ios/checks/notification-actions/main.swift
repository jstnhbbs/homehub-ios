import Foundation

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

let baseURL = URL(string: "https://example.com")!
let recipient = NotificationRecipient(userId: "original-user", householdId: "original-home")
let chore = NotificationCommand.completeChore(choreId: "chore", periodKey: "once", title: "Bins")
let tappedAt = Date(timeIntervalSince1970: 1_790_000_000)

struct Fixture {
    let secrets = InMemorySecretStore()
    let credentials: SessionCredentials
    init() {
        secrets.write(try! JSONEncoder().encode(["session": "old"]), account: "https://example.com")
        credentials = SessionCredentials(baseURL: baseURL, store: secrets, readOnly: true)
    }
    func perform(_ command: NotificationCommand = chore, recipient: NotificationRecipient? = recipient,
                 timeout: TimeInterval = 2) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Server.self]
        try await NotificationActionRunner.perform(command, recipient: recipient, tappedAt: tappedAt,
            baseURL: baseURL, timeout: timeout, credentials: credentials, configuration: configuration)
    }
}

func validReply(_ request: URLRequest) -> Server.Reply {
    switch request.url!.path {
    case "/api/auth/get-session": return (200, #"{"user":{"id":"original-user"}}"#, [:], 0)
    case "/api/mobile/v1/household": return (200, #"{"id":"original-home"}"#, [:], 0)
    default: return (200, "{}", [:], 0)
    }
}

func body(_ request: URLRequest) -> [String: Any] {
    var data = request.httpBody
    if data == nil, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            received.append(buffer, count: count)
        }
        data = received
    }
    return (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
}

@main struct Checks {
    static func main() async {
        do {
            var writes = 0
            Server.handler = { request in
                if request.httpMethod == "POST" {
                    writes += 1
                    let payload = body(request)
                    check("chore sends the desired state and the notification's period", payload["completed"] as? Bool == true && payload["periodKey"] as? String == "once")
                    check("write uses the original cookie", request.value(forHTTPHeaderField: "Cookie") == "session=old")
                }
                return validReply(request)
            }
            try await Fixture().perform()
            check("verified recipient writes once", writes == 1)
        } catch { check("valid chore succeeds: \(error)", false) }
        do {
            Server.handler = { request in
                if request.httpMethod == "POST" {
                    let payload = body(request)
                    check("Wake Up sends the tapped sleep", payload["action"] as? String == "end" && payload["napId"] as? String == "nap")
                    let date = (payload["endedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
                    check("Wake Up preserves the time of the tap", date == tappedAt)
                }
                return validReply(request)
            }
            try await Fixture().perform(.endSleep(sleepId: "nap", name: "Ada"))
        } catch { check("valid sleep succeeds: \(error)", false) }
        for mismatch in ["user", "household", "legacy", "sign-out", "account-switch"] {
            let fixture = Fixture()
            var writes = 0
            Server.handler = { request in
                if request.httpMethod == "POST" { writes += 1 }
                if request.url!.path == "/api/auth/get-session" {
                    if mismatch == "user" { return (200, #"{"user":{"id":"other"}}"#, [:], 0) }
                    if mismatch == "sign-out" { fixture.secrets.delete(account: "https://example.com") }
                    if mismatch == "account-switch" {
                        fixture.secrets.write(try! JSONEncoder().encode(["session": "new"]), account: "https://example.com")
                    }
                }
                if mismatch == "household", request.url!.path == "/api/mobile/v1/household" {
                    return (200, #"{"id":"other-home"}"#, [:], 0)
                }
                return validReply(request)
            }
            do {
                try await fixture.perform(recipient: mismatch == "legacy" ? nil : recipient)
                check("\(mismatch) is refused", false)
            } catch { check("\(mismatch) cannot write", writes == 0) }
            if mismatch == "account-switch" {
                check("old responses preserve the new account", SessionCredentials(baseURL: baseURL, store: fixture.secrets).cookieHeader(for: baseURL) == "session=new")
            }
        }
        for slowStage in ["verification", "write"] {
            Server.handler = { request in
                if slowStage == "verification" || request.httpMethod == "POST" { return (200, "{}", [:], 5) }
                return validReply(request)
            }
            let start = Date()
            do { try await Fixture().perform(timeout: 0.15); check("deadline throws", false) }
            catch {
                check("\(slowStage) deadline completes promptly", Date().timeIntervalSince(start) < 1)
                check("\(slowStage) deadline is a reportable timeout", (error as? URLError)?.code == .timedOut)
            }
        }
        do {
            Server.handler = { _ in (200, "{}", [:], 5) }
            let task = Task { try await Fixture().perform() }
            try? await Task.sleep(for: .milliseconds(30))
            task.cancel()
            do { try await task.value; check("caller cancellation throws", false) }
            catch { check("caller cancellation stays silent rather than becoming a timeout", error.isCancellation) }
        }
        if failures > 0 { exit(1) }
        print("all notification action checks passed")
    }
}
