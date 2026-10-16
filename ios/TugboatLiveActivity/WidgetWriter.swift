import Foundation
import WidgetKit

/// Runs a widget check-off or End Sleep inside the extension.
///
/// The change is shown first, from the saved snapshot, and this returns so iOS can redraw the widget at
/// once; the write to the server carries on behind it. If it fails the item is put back and the error is
/// shown in the widget. The sign-in is the app's own session, read from the Keychain item the app and
/// this extension share (the `keychain-access-groups` entitlement on both).
enum WidgetWriter {
    static func perform(action: String, itemId: String, userId: String, householdId: String, localDate: String) async throws {
        let store = WidgetStore()
        guard let saved = store.load(), saved.userId == userId, saved.householdId == householdId,
              let server = saved.serverURL else { throw WidgetActionFailure.openApp }
        guard let early = WidgetActionPolicy.appliedEarly(action: action, itemId: itemId, userId: userId,
                                                          householdId: householdId, localDate: localDate, to: saved),
              let write = WidgetActionPolicy.writeRequest(action: action, itemId: itemId, in: saved)
        else { throw WidgetActionFailure.stale }
        guard store.save(early, force: true) else { throw WidgetActionFailure.failed }
        // Other widgets that show the same item. The one that was tapped redraws when this returns.
        reload(action)

        // Keep the extension alive for the write after this returns.
        let attempt = Attempt()
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Tugboat widget action") { expired in
            if expired {
                if attempt.markExpired() { revert(action: action, itemId: itemId, userId: userId, original: saved, failure: .failed) }
                return
            }
            let finished = DispatchSemaphore(value: 0)
            Task.detached {
                await send(write, to: server, action: action, itemId: itemId, userId: userId, original: saved, attempt: attempt)
                finished.signal()
            }
            finished.wait()
        }
    }

    private static func send(_ write: WidgetWriteRequest, to server: URL, action: String, itemId: String, userId: String,
                             original: WidgetSnapshot, attempt: Attempt) async {
        // Not `SessionCredentials.shared(for:)`: that also runs the app's first-launch migration, which
        // would clear a session it can't find in this process's own defaults.
        let credentials = SessionCredentials(baseURL: server)
        guard credentials.hasSession else {
            if attempt.markFinished() { revert(action: action, itemId: itemId, userId: userId, original: original, failure: .openApp) }
            return
        }
        do {
            try await APIClient(baseURL: server, credentials: credentials).requestVoid(write.path, method: "POST", body: write.body)
            _ = attempt.markFinished()
            WidgetWriteSignal.recordWrite()
        } catch {
            guard attempt.markFinished() else { return }
            if case APIError.unauthorized = error {
                revert(action: action, itemId: itemId, userId: userId, original: original, failure: .openApp)
            } else {
                revert(action: action, itemId: itemId, userId: userId, original: original, failure: .failed)
            }
        }
    }

    /// Puts the one item back and says why, in whatever the snapshot is by now.
    private static func revert(action: String, itemId: String, userId: String, original: WidgetSnapshot, failure: WidgetActionFailure) {
        let store = WidgetStore()
        guard let current = store.load(), current.userId == userId else { return }
        var snapshot = WidgetActionPolicy.reverted(action: action, itemId: itemId, in: current, from: original)
        snapshot.actionError = failure.localizedDescription
        _ = store.save(snapshot, force: true)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func reload(_ action: String) {
        for kind in WidgetActionPolicy.affectedKinds(action: action) { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }

    /// Whether the write has finished or been given up on, so only one of those puts the item back.
    private final class Attempt: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func markFinished() -> Bool { lock.withLock { let first = !done; done = true; return first } }
        func markExpired() -> Bool { markFinished() }
    }
}
