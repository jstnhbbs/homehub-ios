import Foundation

/// Notification-center writes must finish before session cleanup or a newer plan can write.
@MainActor
final class NotificationWorkQueue {
    private var revision = 0
    private var tail: Task<Void, Never>?

    func schedule(_ operation: @escaping @MainActor (_ isCurrent: @escaping @MainActor () -> Bool) async -> Void) async {
        revision += 1
        let version = revision
        let previous = tail
        let task = Task {
            await previous?.value
            guard version == revision else { return }
            await operation { version == self.revision }
            if version == revision { tail = nil }
        }
        tail = task
        await task.value
    }

    /// Invalidates older planners immediately, then clears after any add already in flight.
    @discardableResult
    func reset(_ cleanup: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        revision += 1
        let version = revision
        let previous = tail
        let task = Task {
            await previous?.value
            await cleanup()
            if version == revision { tail = nil }
        }
        tail = task
        return task
    }
}
