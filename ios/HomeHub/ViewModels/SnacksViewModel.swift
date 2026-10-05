import Foundation

@MainActor
final class SnacksViewModel: ObservableObject {
    @Published var snackOptions: [String] = []
    @Published var eaten: Set<String> = []
    /// Who has had what today, for households that track snacks per child.
    @Published var records: [SnackEatenRecord] = []
    @Published var children: [Profile] = []
    @Published var tracksPerChild = false
    @Published var newSnackText = ""
    @Published var editingSnack: String?
    @Published var editDraft = ""
    @Published var localDate = ""
    @Published var dateLabel = ""
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    /// Per-child tracking is on and there is a child to track.
    var usesPerChild: Bool { tracksPerChild && !children.isEmpty }

    /// Per-child tracking can only be switched on once there is a child.
    var canChoosePerChild: Bool { !children.isEmpty }

    var displayedSnacks: [String] {
        SnackHelpers.sortedSnackOptions(snackOptions, eaten: eaten)
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await appState.refreshDashboard()
        guard let dashboard = appState.dashboard else { return }

        syncFromDashboard(dashboard)
        localDate = dashboard.localDate

        if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
            dateLabel = DateHelpers.formatLocalDate(dashboard.localDate, timezone: timezone, style: .full)
        } else {
            dateLabel = dashboard.localDate
        }
    }

    private func syncFromDashboard(_ dashboard: DashboardData) {
        snackOptions = dashboard.snackOptions
        eaten = Set(dashboard.snackEaten)
        records = dashboard.snackCompletions
        tracksPerChild = dashboard.snacksPerChild
        children = NapHelpers.childProfiles(from: dashboard.profiles)
    }

    func setPerChild(_ enabled: Bool) async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }
        do {
            let household = try await appState.api.saveSnackOptions(
                SaveSnackOptionsRequest(snackOptions: nil, snacksPerChild: enabled)
            )
            appState.household = household
            await appState.refreshDashboard()
            if let dashboard = appState.dashboard {
                syncFromDashboard(dashboard)
            }
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    /// `profileId` is the child who ate it when snacks are tracked per child. `completed` is the
    /// state to leave it in (eaten or not); nil flips it.
    func toggleSnack(_ label: String, profileId: String? = nil, completed: Bool? = nil) async {
        guard let appState else { return }
        do {
            try await appState.toggleSnack(localDate: localDate, label: label, profileId: profileId, completed: completed)
            // Prefer the refreshed server state; fall back to a local flip if the
            // dashboard isn't loaded for some reason.
            if let dashboard = appState.dashboard {
                syncFromDashboard(dashboard)
            } else if eaten.contains(label) {
                eaten.remove(label)
            } else {
                eaten.insert(label)
            }
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func resetChecklist() async {
        guard let appState else { return }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            try await appState.api.resetSnackChecklist(localDate: localDate)
            await load()
            successMessage = "Snack checklist reset."
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    @discardableResult
    func addSnack() async -> Bool {
        let trimmed = newSnackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if snackOptions.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            newSnackText = ""
            return true
        }

        var next = snackOptions
        next.append(trimmed)
        let saved = await persistSnackOptions(next)
        if saved {
            newSnackText = ""
        }
        return saved
    }

    func deleteSnack(_ label: String) async {
        if editingSnack == label {
            cancelEditing()
        }
        let next = snackOptions.filter { $0 != label }
        await persistSnackOptions(next)
    }

    func beginEditing(_ label: String) {
        editingSnack = label
        editDraft = label
    }

    func cancelEditing() {
        editingSnack = nil
        editDraft = ""
    }

    @discardableResult
    func commitEditing() async -> Bool {
        guard let original = editingSnack else { return false }
        let trimmed = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEditing()
            return false
        }

        if trimmed.caseInsensitiveCompare(original) == .orderedSame {
            // Keep original casing if unchanged ignoring case and equal.
            if trimmed == original {
                cancelEditing()
                return true
            }
        } else if snackOptions.contains(where: {
            $0 != original && $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            errorMessage = "That snack is already on the list."
            return false
        }

        var next = snackOptions
        guard let index = next.firstIndex(of: original) else {
            cancelEditing()
            return false
        }
        next[index] = trimmed

        let saved = await persistSnackOptions(next)
        if saved {
            if eaten.contains(original) {
                eaten.remove(original)
                eaten.insert(trimmed)
            }
            cancelEditing()
        }
        return saved
    }

    @discardableResult
    private func persistSnackOptions(_ lines: [String]) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        let serialized = SnackHelpers.serializeSnackOptions(lines)

        do {
            let household = try await appState.api.saveSnackOptions(
                SaveSnackOptionsRequest(snackOptions: serialized, snacksPerChild: nil)
            )
            appState.household = household
            snackOptions = lines
            await appState.refreshDashboard()
            if let dashboard = appState.dashboard {
                syncFromDashboard(dashboard)
            }
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }
}
