import Foundation
import WidgetKit

/// Replays durable widget taps using one verified account and one bounded network session.
enum WidgetSync {
    enum Outcome: Equatable, Sendable {
        case sent
        case retry(after: TimeInterval?)
        case rejected(WidgetActionFailure)
        case signedOut
    }

    private struct SessionIdentity: Decodable {
        struct User: Decodable { let id: String }
        let user: User?
    }

    private static func send(_ pending: WidgetPendingAction, client: APIClient, timeout: TimeInterval) async -> Outcome {
        guard let write = pending.writeRequest() else { return .rejected(.stale) }
        do {
            try await client.requestVoid(write.path, method: "POST", body: write.body, timeout: timeout)
            return .sent
        } catch {
            if case APIError.unauthorized = error { return .signedOut }
            if case APIError.retryableServerError(_, _, let delay) = error { return .retry(after: delay) }
            if error.isCancellation || WidgetNetworkFailure.isOffline(error) { return .retry(after: nil) }
            // End Sleep is idempotent even if the first response was lost.
            if pending.action == "endSleep", let message = (error as? APIError)?.errorDescription,
               message.localizedCaseInsensitiveContains("not found") { return .sent }
            return .rejected(.failed)
        }
    }

    /// Claims one tap at a time so a backlog cannot outlive the claims of items not yet sent.
    /// Injection is used by the checks; production always creates a read-only Keychain snapshot.
    @discardableResult
    static func flush(store: WidgetStore = WidgetStore(), queue: WidgetPendingQueue = WidgetPendingQueue(),
                      timeout: TimeInterval = 20, credentials suppliedCredentials: SessionCredentials? = nil,
                      configuration suppliedConfiguration: URLSessionConfiguration? = nil) async -> Bool {
        guard !Task.isCancelled, timeout > 0, let snapshot = store.load(), let server = snapshot.serverURL else { return false }
        let credentials = suppliedCredentials ?? SessionCredentials(baseURL: server, readOnly: true)
        func isCurrent() -> Bool {
            guard !Task.isCancelled, credentials.hasSession, credentials.isCurrent, let current = store.load() else { return false }
            return current.userId == snapshot.userId && current.householdId == snapshot.householdId && current.serverURL == server
        }
        guard isCurrent() else { return false }
        let configuration = suppliedConfiguration ?? URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        let client = APIClient(baseURL: server, session: session, credentials: credentials)
        // Cancelling the actual URLSession ends a pending request; cancelling a child awaiting a detached
        // task does not. This deadline covers verification and the entire batch, including slow streaming.
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(timeout)) } catch { return }
            session.invalidateAndCancel()
        }
        defer { deadline.cancel(); session.invalidateAndCancel() }
        return await withTaskCancellationHandler {
            var accepted = false
            var changedKinds = Set<String>()
            defer {
                if accepted { WidgetWriteSignal.recordWrite() }
                for kind in changedKinds.sorted() { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
            }
            do {
                let identity: SessionIdentity? = try await client.request("/api/auth/get-session", timeout: timeout)
                guard isCurrent(), identity?.user?.id == snapshot.userId else { return false }
            } catch {
                // A locked Keychain, unreachable auth service or changed session must not lose waiting taps.
                return false
            }
            let end = Date().addingTimeInterval(timeout)
            while isCurrent(), Date() < end,
                  let item = queue.claim(userId: snapshot.userId, householdId: snapshot.householdId, limit: 1).first {
                let outcome = await send(item, client: client, timeout: timeout)
                guard isCurrent() else { queue.release(id: item.id); return accepted }
                changedKinds.formUnion(WidgetActionPolicy.affectedKinds(action: item.action))
                switch outcome {
                case .sent:
                    queue.remove(id: item.id)
                    accepted = true
                case .retry(let delay):
                    queue.retry(item.id, after: delay)
                    return accepted
                case .rejected(let failure):
                    queue.remove(id: item.id)
                    undo(item, failure: failure, store: store)
                case .signedOut:
                    queue.clear(userId: snapshot.userId, householdId: snapshot.householdId)
                    undo(item, failure: .openApp, store: store)
                    return accepted
                }
            }
            return accepted
        } onCancel: {
            session.invalidateAndCancel()
        }
    }

    private static func undo(_ item: WidgetPendingAction, failure: WidgetActionFailure, store: WidgetStore) {
        guard let current = store.load(), item.applies(to: current) else { return }
        var snapshot = WidgetActionPolicy.undoing(action: item.action, itemId: item.itemId, in: current)
        snapshot.actionError = failure.localizedDescription
        _ = store.save(snapshot, force: true)
    }
}
