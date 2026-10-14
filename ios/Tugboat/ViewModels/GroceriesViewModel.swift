import Foundation

@MainActor
final class GroceriesViewModel: ObservableObject {
    @Published var items: [GroceryItem] = []
    @Published var newItemTitle = ""
    @Published var reminderLists: [ReminderListOption] = []
    @Published var selectedReminderListId: String?
    @Published var remindersAccessStatus: NativeRemindersAccessStatus = .notDetermined
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var uncheckedItems: [GroceryItem] {
        GroceryHelpers.sortedItems(items.filter { !$0.checked })
    }

    var checkedItems: [GroceryItem] {
        GroceryHelpers.sortedItems(items.filter(\.checked))
    }

    var uncheckedGroups: [(category: String, items: [GroceryItem])] {
        GroceryHelpers.groupedItems(uncheckedItems)
    }

    var usesNativeReminders: Bool {
        remindersAccessStatus == .authorized
    }

    var needsRemindersPermission: Bool {
        remindersAccessStatus == .notDetermined
    }

    var remindersDenied: Bool {
        remindersAccessStatus == .denied || remindersAccessStatus == .restricted
    }

    var canSelectReminderList: Bool {
        appState?.canManageHousehold ?? false
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            syncReminderState(from: appState)
            if usesNativeReminders {
                items = try await appState.nativeReminders.loadItems()
                appState.nativeGroceryItems = items
            } else {
                items = try await appState.api.fetchGroceryItems()
            }
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func requestRemindersAccess() async {
        guard let appState else { return }
        await appState.nativeReminders.requestFullAccess()
        syncReminderState(from: appState)
        await load()
    }

    func selectReminderList(id: String?) {
        guard let appState, appState.canManageHousehold else { return }
        appState.nativeReminders.selectedListId = id
        syncReminderState(from: appState)
        Task { await load() }
    }

    func addItem() async {
        guard let appState else { return }
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            if usesNativeReminders {
                _ = try appState.nativeReminders.addItem(title: title)
                items = try await appState.nativeReminders.loadItems()
                appState.nativeGroceryItems = items
            } else {
                let created = try await appState.api.addGroceryItem(
                    GroceryItemInput(title: title, category: nil)
                )
                items.insert(created, at: 0)
                items = GroceryHelpers.sortedItems(items)
            }
            newItemTitle = ""
            await appState.refreshDashboard()
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func toggle(_ item: GroceryItem) async {
        guard let appState else { return }
        let nextChecked = !item.checked
        updateLocalItem(item.id) { draft in
            draft.checked = nextChecked
            draft.checkedAt = nextChecked ? Date() : nil
        }

        do {
            if usesNativeReminders {
                try appState.nativeReminders.setCompleted(itemId: item.id, completed: nextChecked)
                items = try await appState.nativeReminders.loadItems()
                appState.nativeGroceryItems = items
            } else {
                let updated = try await appState.api.toggleGroceryItem(id: item.id, checked: nextChecked)
                updateLocalItem(item.id) { $0 = updated }
            }
            await appState.refreshDashboard()
        } catch {
            updateLocalItem(item.id) { draft in
                draft.checked = item.checked
                draft.checkedAt = item.checkedAt
            }
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func delete(_ item: GroceryItem) async {
        guard let appState else { return }
        let previous = items
        items.removeAll { $0.id == item.id }

        do {
            if usesNativeReminders {
                try appState.nativeReminders.deleteItem(itemId: item.id)
                appState.nativeGroceryItems = items
            } else {
                try await appState.api.deleteGroceryItem(id: item.id)
            }
            await appState.refreshDashboard()
        } catch {
            items = previous
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func clearChecked() async {
        guard let appState else { return }
        let previous = items
        items.removeAll { $0.checked }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            if usesNativeReminders {
                for item in previous where item.checked {
                    try appState.nativeReminders.deleteItem(itemId: item.id)
                }
                appState.nativeGroceryItems = items
            } else {
                try await appState.api.clearCheckedGroceryItems()
            }
            await appState.refreshDashboard()
        } catch {
            items = previous
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    private func updateLocalItem(_ id: String, update: (inout GroceryItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        update(&items[index])
        items = GroceryHelpers.sortedItems(items)
    }

    private func syncReminderState(from appState: AppState) {
        appState.nativeReminders.refreshAccessStatus()
        remindersAccessStatus = appState.nativeReminders.accessStatus
        reminderLists = appState.nativeReminders.reminderLists()
        selectedReminderListId = appState.nativeReminders.usesAutomaticList
            ? NativeCalendarPreferenceKeys.automaticId
            : appState.nativeReminders.selectedListId
    }
}
