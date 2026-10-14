import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

@MainActor
func run() async throws {
    let composer = NoteComposer()
    var calls = 0
    composer.draft = " \n "
    let empty = try await composer.submit { _ in calls += 1 }
    check("empty drafts never send a request", !empty && calls == 0)

    composer.draft = "  Picture day  "
    var gate: CheckedContinuation<Void, Never>?
    var submitted = ""
    let slowSave = Task {
        try await composer.submit { title in
            calls += 1
            submitted = title
            await withCheckedContinuation { gate = $0 }
        }
    }
    for _ in 0..<1000 {
        if gate != nil { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    check("a slow request keeps the draft and shows saving", gate != nil && composer.isSaving && composer.draft == "  Picture day  ")
    check("only trimmed text is sent", submitted == "Picture day")
    let duplicate = try await composer.submit { _ in calls += 1 }
    check("repeated taps cannot send a second pending request", !duplicate && calls == 1)
    composer.draft = "Next note"
    gate?.resume()
    _ = try await slowSave.value
    check("newly typed text survives the earlier save", composer.draft == "Next note" && !composer.isSaving && composer.canSubmit)

    composer.draft = "Same note"
    gate = nil
    let retypedSave = Task {
        try await composer.submit { _ in
            await withCheckedContinuation { gate = $0 }
        }
    }
    for _ in 0..<1000 {
        if gate != nil { break }
        try await Task.sleep(for: .milliseconds(1))
    }
    check("retyped-note request reached its delay", gate != nil)
    composer.draft = ""
    composer.draft = "Same note"
    gate?.resume()
    _ = try await retypedSave.value
    check("retyping the same text is still a new draft", composer.draft == "Same note")

    for code in [URLError.notConnectedToInternet, .timedOut, .networkConnectionLost, .cancelled] {
        composer.draft = "Keep this draft"
        var threw = false
        do {
            try await composer.submit { _ in throw URLError(code) }
        } catch { threw = true }
        check("\(code.rawValue): failure preserves draft and releases saving", threw && composer.draft == "Keep this draft" && !composer.isSaving && composer.canSubmit)
    }
    let retry = try await composer.submit { title in
        check("retry uses the retained draft", title == "Keep this draft")
    }
    check("successful retry clears only the submitted draft", retry && composer.draft.isEmpty && !composer.isSaving)
    check("cleared draft cannot be submitted again", !composer.canSubmit)

    if failures > 0 { exit(1) }
    print("all passed")
    exit(0)
}

Task {
    do { try await run() } catch { print("FAIL unexpected error: \(error)"); exit(1) }
}
RunLoop.main.run()
