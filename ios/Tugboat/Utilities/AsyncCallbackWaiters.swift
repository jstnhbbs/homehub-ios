import Foundation

/// Shares one delegate request without replacing callers, and bounds each caller's wait.
@MainActor
final class AsyncCallbackWaiters<Value: Sendable> {
    private var continuations: [UUID: CheckedContinuation<Value, Error>] = [:]
    private var timeouts: [UUID: Task<Void, Never>] = [:]

    func wait(timeout: Duration, timeoutError: Error, start: () -> Void = {}) async throws -> Value {
        let id = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let first = continuations.isEmpty
                continuations[id] = continuation
                timeouts[id] = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.finish(id, result: .failure(timeoutError))
                }
                if first { start() }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(id, result: .failure(CancellationError()))
            }
        }
    }

    func resolve(_ result: Result<Value, Error>) {
        for id in Array(continuations.keys) { finish(id, result: result) }
    }

    private func finish(_ id: UUID, result: Result<Value, Error>) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        timeouts.removeValue(forKey: id)?.cancel()
        continuation.resume(with: result)
    }

    deinit {
        for timeout in timeouts.values { timeout.cancel() }
        for continuation in continuations.values { continuation.resume(throwing: CancellationError()) }
    }
}
