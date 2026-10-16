import Foundation
import WidgetKit

/// Sends the taps waiting in `WidgetPendingQueue`. Used by the widget (right after a tap, and when it is
/// asked for a new picture) and by the app (when it comes to the front or the connection returns).
enum WidgetSync {
    enum Outcome: Equatable, Sendable {
        case sent
        /// No connection: the tap stays, and is tried again later.
        case offline
        /// The server refused it (or it could not be built): the tap is undone and the reason shown.
        case rejected(WidgetActionFailure)
        /// There is no usable sign-in.
        case signedOut
    }

    /// Sends one tap, reading the sign-in from the Keychain item shared with the app.
    static func send(_ pending: WidgetPendingAction, to server: URL, timeout: TimeInterval = 20) async -> Outcome {
        guard let write = pending.writeRequest() else { return .rejected(.stale) }
        // Not `SessionCredentials.shared(for:)`: that also runs the app's first-launch migration, which
        // would clear a session it can't find in this process's own defaults.
        let credentials = SessionCredentials(baseURL: server)
        guard credentials.hasSession else { return .signedOut }
        do {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            configuration.timeoutIntervalForRequest = timeout
            let client = APIClient(baseURL: server, session: URLSession(configuration: configuration), credentials: credentials)
            try await client.requestVoid(write.path, method: "POST", body: write.body)
            return .sent
        } catch {
            if case APIError.unauthorized = error { return .signedOut }
            if WidgetNetworkFailure.isOffline(error) { return .offline }
            // A second send of End Sleep (the first got through but its answer was lost) finds nothing to end.
            if pending.action == "endSleep", let message = (error as? APIError).flatMap({ $0.errorDescription }),
               message.localizedCaseInsensitiveContains("not found") { return .sent }
            return .rejected(.failed)
        }
    }

    /// Sends what is waiting, oldest first, and stops at the first one that finds no connection. Returns
    /// whether the server accepted anything. Safe to run from the widget and the app at once: each tap is
    /// taken by one sender at a time.
    @discardableResult
    static func flush(store: WidgetStore = WidgetStore(), queue: WidgetPendingQueue = WidgetPendingQueue(),
                      timeout: TimeInterval = 20) async -> Bool {
        guard let snapshot = store.load(), let server = snapshot.serverURL else { return false }
        let claimed = queue.claim(userId: snapshot.userId)
        guard !claimed.isEmpty else { return false }
        var accepted = false
        var changedKinds = Set<String>()
        for item in claimed {
            let outcome = await send(item, to: server, timeout: timeout)
            changedKinds.formUnion(WidgetActionPolicy.affectedKinds(action: item.action))
            switch outcome {
            case .sent:
                queue.remove(id: item.id)
                accepted = true
            case .offline:
                queue.release(id: item.id)
                for later in claimed where later.id != item.id { queue.release(id: later.id) }
                reload(changedKinds)
                return accepted
            case .rejected(let failure):
                queue.remove(id: item.id)
                undo(item, failure: failure, store: store)
            case .signedOut:
                queue.clear()
                undo(item, failure: .openApp, store: store)
            }
        }
        if accepted { WidgetWriteSignal.recordWrite() }
        reload(changedKinds)
        return accepted
    }

    /// Puts one refused tap back in the saved snapshot and says why.
    private static func undo(_ item: WidgetPendingAction, failure: WidgetActionFailure, store: WidgetStore) {
        guard let current = store.load(), current.userId == item.userId else { return }
        var snapshot = WidgetActionPolicy.undoing(action: item.action, itemId: item.itemId, in: current)
        snapshot.actionError = failure.localizedDescription
        _ = store.save(snapshot, force: true)
    }

    private static func reload(_ kinds: Set<String>) {
        for kind in kinds.sorted() { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }
}
