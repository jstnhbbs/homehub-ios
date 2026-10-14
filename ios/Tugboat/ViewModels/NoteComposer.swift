import Combine
import Foundation

@MainActor
final class NoteComposer: ObservableObject {
    @Published var draft = "" {
        didSet {
            if draft != oldValue { draftRevision += 1 }
        }
    }
    @Published private(set) var isSaving = false
    private var draftRevision = 0

    var canSubmit: Bool {
        !isSaving && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Keep a failed draft, and never erase a new draft typed while this request was running.
    @discardableResult
    func submit(save: (String) async throws -> Void) async throws -> Bool {
        guard canSubmit else { return false }
        let submitted = draft
        let submittedRevision = draftRevision
        let title = submitted.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        defer { isSaving = false }

        try await save(title)
        if draftRevision == submittedRevision { draft = "" }
        return true
    }
}
