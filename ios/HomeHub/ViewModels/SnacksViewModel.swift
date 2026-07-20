import Foundation

@MainActor
final class SnacksViewModel: ObservableObject {
    @Published var snackOptions: [String] = []
    @Published var eaten: Set<String> = []
    @Published var snackOptionsText = ""
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

    var pendingSnacks: [String] {
        snackOptions.filter { !eaten.contains($0) }
    }

    var allEaten: Bool {
        !snackOptions.isEmpty && pendingSnacks.isEmpty
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await appState.refreshDashboard()
        guard let dashboard = appState.dashboard else { return }

        snackOptions = dashboard.snackOptions
        eaten = Set(dashboard.snackEaten)
        localDate = dashboard.localDate
        snackOptionsText = SnackHelpers.serializeSnackOptions(snackOptions)

        if let timezone = appState.household.flatMap({ TimeZone(identifier: $0.timezone) }) {
            dateLabel = DateHelpers.formatLocalDate(dashboard.localDate, timezone: timezone, style: .full)
        } else {
            dateLabel = dashboard.localDate
        }
    }

    func toggleSnack(_ label: String) async {
        guard let appState else { return }
        do {
            try await appState.api.toggleSnack(
                ToggleSnackRequest(localDate: localDate, snackLabel: label)
            )
            eaten.insert(label)
            await appState.refreshDashboard()
            if let dashboard = appState.dashboard {
                eaten = Set(dashboard.snackEaten)
            }
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func saveSnackOptions() async -> Bool {
        guard let appState else { return false }
        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        let lines = snackOptionsText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let serialized = SnackHelpers.serializeSnackOptions(lines)

        do {
            let household = try await appState.api.saveSnackOptions(
                SaveSnackOptionsRequest(snackOptions: serialized)
            )
            appState.household = household
            await load()
            successMessage = "Snack list saved."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
