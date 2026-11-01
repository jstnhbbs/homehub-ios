import Foundation

/// The guided setup's state, kept per household on this device (`HouseholdSetupStore`).
extension AppState {
    /// Reads the saved state for the current household. Cheap; views call it when they appear.
    func loadSetupState() {
        guard let id = household?.id else {
            setupState = nil
            return
        }
        let loaded = HouseholdSetupStore().load(householdId: id)
        if loaded != setupState { setupState = loaded }
    }

    /// Offers setup for a household this device has just created.
    func beginSetup(householdId: String) {
        HouseholdSetupStore().begin(householdId: householdId)
        loadSetupState()
    }

    func updateSetup(_ change: (inout HouseholdSetupState) -> Void) {
        guard let id = household?.id else { return }
        var state = HouseholdSetupStore().load(householdId: id) ?? HouseholdSetupState()
        change(&state)
        HouseholdSetupStore().save(state, householdId: id)
        setupState = state
    }

    func completeSetupStep(_ step: HouseholdSetupStep) {
        updateSetup { $0.complete(step) }
    }

    func openSetup() {
        updateSetup { $0.presented = true }
        showingSetup = true
    }

    /// Closes the card for good (it stays reachable in Settings).
    func dismissSetupCard() {
        updateSetup { $0.dismissed = true }
    }
}
