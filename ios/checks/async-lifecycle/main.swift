import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
enum TestError: Error { case timeout, unavailable }

@MainActor
func until(_ condition: () -> Bool) async {
    for _ in 0..<1000 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(1))
    }
    check("operation started within deadline", false)
}

@MainActor
func run() async {
    let waiters = AsyncCallbackWaiters<Int>()
    var starts = 0
    let first = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { starts += 1 } }
    let second = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { starts += 1 } }
    await until { starts == 1 }
    await Task.yield()
    waiters.resolve(.success(42))
    let firstValue = try? await first.value
    let secondValue = try? await second.value
    check("one delegate request serves overlapping callers", starts == 1 && firstValue == 42 && secondValue == 42)

    var started = false
    let cancelled = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { started = true } }
    await until { started }
    cancelled.cancel()
    do { _ = try await cancelled.value; check("cancelled caller exits", false) }
    catch { check("cancelled caller exits", error is CancellationError) }
    waiters.resolve(.success(99)) // A late callback must not resume the cancelled continuation twice.

    starts = 0
    let departing = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { starts += 1 } }
    let remaining = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { starts += 1 } }
    await until { starts == 1 }
    await Task.yield()
    departing.cancel()
    _ = try? await departing.value
    waiters.resolve(.success(7))
    let remainingValue = try? await remaining.value
    check("cancelling one caller leaves the shared request available to others", remainingValue == 7)

    do {
        _ = try await waiters.wait(timeout: .milliseconds(10), timeoutError: TestError.timeout)
        check("missing delegate callback times out", false)
    } catch { check("missing delegate callback times out", error as? TestError == .timeout) }
    waiters.resolve(.success(99))

    starts = 0
    let failed = Task { try await waiters.wait(timeout: .seconds(2), timeoutError: TestError.timeout) { starts += 1 } }
    await until { starts == 1 }
    waiters.resolve(.failure(TestError.unavailable))
    do { _ = try await failed.value; check("delegate failure resumes caller", false) }
    catch { check("delegate failure resumes caller", error as? TestError == .unavailable) }

    let queue = NotificationWorkQueue()
    let addGate = AsyncCallbackWaiters<Void>()
    var adding = false
    var events: [String] = []
    var reminders: [String] = []
    let oldPlan = Task {
        await queue.schedule { isCurrent in
            adding = true
            try? await addGate.wait(timeout: .seconds(2), timeoutError: TestError.timeout)
            reminders.append("old") // Simulates an OS add that already started before logout.
            events.append("old-add-finished")
            if isCurrent() { reminders.append("another-old") }
        }
    }
    await until { adding }
    let cleanup = queue.reset {
        reminders = []
        events.append("cleared")
    }
    let newPlan = Task {
        await queue.schedule { _ in
            reminders.append("new")
            events.append("new-added")
        }
    }
    addGate.resolve(.success(()))
    await oldPlan.value
    await cleanup.value
    await newPlan.value
    check("logout waits for in-flight adds before clearing", events == ["old-add-finished", "cleared", "new-added"])
    check("old reminders cannot reappear or erase the new account's plan", reminders == ["new"])

    let gate = AsyncCallbackWaiters<Void>()
    var running = false
    var queued = false
    var obsoleteRan = false
    let active = Task {
        await queue.schedule { _ in
            running = true
            try? await gate.wait(timeout: .seconds(2), timeoutError: TestError.timeout)
        }
    }
    await until { running }
    let obsolete = Task {
        queued = true
        await queue.schedule { _ in obsoleteRan = true }
    }
    await until { queued }
    let cleared = queue.reset {}
    gate.resolve(.success(()))
    await active.value
    await obsolete.value
    await cleared.value
    check("a queued old plan is discarded on logout", !obsoleteRan)

    weak var releasedQueue: NotificationWorkQueue?
    do {
        let temporaryQueue = NotificationWorkQueue()
        releasedQueue = temporaryQueue
        await temporaryQueue.schedule { _ in }
    }
    await Task.yield()
    check("completed scheduling does not retain its queue", releasedQueue == nil)

    weak var releasedWaiters: AsyncCallbackWaiters<Int>?
    do {
        let temporaryWaiters = AsyncCallbackWaiters<Int>()
        releasedWaiters = temporaryWaiters
        _ = try? await temporaryWaiters.wait(timeout: .milliseconds(1), timeoutError: TestError.timeout)
    }
    await Task.yield()
    check("a timed-out wait does not retain its waiter storage", releasedWaiters == nil)

    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
