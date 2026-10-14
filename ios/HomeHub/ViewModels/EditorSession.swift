import Combine
import Foundation

@MainActor
final class EditorSession: ObservableObject {
    @Published private(set) var hasChanges = false
    @Published private(set) var isBusy = false
    @Published var confirmDiscard = false

    var preventsInteractiveDismissal: Bool { hasChanges || isBusy }

    func updateChanges(_ changed: Bool) {
        if hasChanges != changed { hasChanges = changed }
    }

    func requestDismissal() -> Bool {
        guard !isBusy else { return false }
        guard !hasChanges else {
            confirmDiscard = true
            return false
        }
        return true
    }

    func beginOperation() -> Bool {
        guard !isBusy else { return false }
        confirmDiscard = false
        isBusy = true
        return true
    }

    func endOperation() { isBusy = false }
}
