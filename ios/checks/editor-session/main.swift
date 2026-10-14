import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

@MainActor
func run() async {
    let session = EditorSession()
    check("clean editors allow dismissal", session.requestDismissal() && !session.preventsInteractiveDismissal)
    session.updateChanges(true)
    check("edits block swipe dismissal", session.preventsInteractiveDismissal)
    check("Cancel asks before discarding edits", !session.requestDismissal() && session.confirmDiscard)
    session.confirmDiscard = false
    session.updateChanges(false)
    check("reverting edits makes the editor clean", session.requestDismissal() && !session.preventsInteractiveDismissal)
    session.updateChanges(true)
    _ = session.requestDismissal()
    check("operation starts and clears stale discard prompt", session.beginOperation() && session.isBusy && !session.confirmDiscard)
    check("overlapping save or delete is refused", !session.beginOperation())
    check("busy Cancel does not show discard prompt", !session.requestDismissal() && !session.confirmDiscard)
    session.updateChanges(false)
    check("even a clean editor cannot close during a write", session.preventsInteractiveDismissal && !session.requestDismissal())
    session.updateChanges(true)
    await Task.yield()
    check("slow operations remain protected", session.isBusy && session.preventsInteractiveDismissal)
    session.endOperation()
    check("failed write releases busy state without discarding draft", !session.isBusy && session.hasChanges)
    check("failed writes can be retried", session.beginOperation())
    session.updateChanges(false)
    session.endOperation()
    check("successful save can dismiss", session.requestDismissal() && !session.preventsInteractiveDismissal)
    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}

Task { await run() }
RunLoop.main.run()
