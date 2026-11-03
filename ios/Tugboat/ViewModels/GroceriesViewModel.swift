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

    var canManage: Bool { appState?.canManageHousehold ?? false }

    private var loadVersion = 0

    private struct Context {
        let session: Int
        let userId: String?
        let householdId: String?
        let native: Bool
        let listId: String?
    }

    private func context(_ app: AppState) -> Context {
        Context(session: app.auth.sessionVersion, userId: app.currentUser?.id, householdId: app.household?.id,
                native: app.nativeReminders.hasFullAccess, listId: app.nativeReminders.selectedListId)
    }

    private func isCurrent(_ context: Context, in app: AppState) -> Bool {
        !Task.isCancelled && app.auth.isSignedIn && context.session == app.auth.sessionVersion
            && context.userId == app.currentUser?.id && context.householdId == app.household?.id
            && context.native == app.nativeReminders.hasFullAccess && context.listId == app.nativeReminders.selectedListId
    }

    func load() async {
        guard let appState, !isWorking else { return }
        syncReminderState(from: appState)
        loadVersion += 1
        let version = loadVersion
        let remindersRevision = appState.nativeReminders.revision
        let context = context(appState)
        isLoading = true
        errorMessage = nil
        defer { if version == loadVersion { isLoading = false } }
        do {
            let fetched = context.native ? try await appState.nativeReminders.loadItems() : try await appState.api.fetchGroceryItems()
            guard version == loadVersion, isCurrent(context, in: appState) else { return }
            guard remindersRevision == appState.nativeReminders.revision else {
                Task { await load() }
                return
            }
            items = fetched
            if context.native { appState.nativeGroceryItems = fetched }
        } catch {
            guard version == loadVersion, isCurrent(context, in: appState) else { return }
            if remindersRevision != appState.nativeReminders.revision {
                Task { await load() }
                return
            }
            errorMessage = error.userFacingMessage
        }
    }

    func requestRemindersAccess() async {
        guard let appState else { return }
        await appState.nativeReminders.requestFullAccess()
        await load()
    }

    func selectReminderList(id: String?) {
        guard let appState, canManage, !isWorking else { return }
        loadVersion += 1
        items = []
        appState.nativeGroceryItems = []
        appState.nativeReminders.selectedListId = id
        syncReminderState(from: appState)
        Task { await load() }
    }

    /// Reserve the write before any suspension, and invalidate older reads before optimistic edits.
    private func beginWrite(_ app: AppState) -> Context? {
        guard app.canManageHousehold, !isWorking, app.auth.isSignedIn else { return nil }
        syncReminderState(from: app)
        loadVersion += 1
        isLoading = false
        isWorking = true
        errorMessage = nil
        return context(app)
    }

    private func report(_ error: Error, in app: AppState) {
        errorMessage = error.userFacingMessage
        app.report(error)
    }

    func addItem() async {
        guard let appState else { return }
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let context = beginWrite(appState) else { return }
        defer { isWorking = false }
        do {
            if context.native {
                let created = try appState.nativeReminders.addItem(title: title)
                items.insert(created, at: 0)
                items = GroceryHelpers.sortedItems(items)
                appState.nativeGroceryItems = items
                // The write already committed. A cancelled reconciliation must not turn it into a failed Add.
                let fetched = try? await appState.nativeReminders.loadItems()
                guard isCurrent(context, in: appState) else { return }
                if let fetched { items = fetched; appState.nativeGroceryItems = fetched }
            } else {
                let created = try await appState.api.addGroceryItem(GroceryItemInput(title: title, category: nil))
                guard isCurrent(context, in: appState) else { return }
                items.insert(created, at: 0)
                items = GroceryHelpers.sortedItems(items)
            }
            // Keep a new draft typed while this request was pending.
            if newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines) == title { newItemTitle = "" }
            await appState.refreshDashboard()
        } catch {
            guard isCurrent(context, in: appState) else { return }
            report(error, in: appState)
        }
    }

    func toggle(_ item: GroceryItem) async {
        guard let appState, let context = beginWrite(appState) else { return }
        defer { isWorking = false }
        let nextChecked = !item.checked
        updateLocalItem(item.id) { $0.checked = nextChecked; $0.checkedAt = nextChecked ? Date() : nil }
        do {
            if context.native {
                try appState.nativeReminders.setCompleted(itemId: item.id, completed: nextChecked)
                appState.nativeGroceryItems = items
                let fetched = try? await appState.nativeReminders.loadItems()
                guard isCurrent(context, in: appState) else { return }
                if let fetched { items = fetched; appState.nativeGroceryItems = fetched }
            } else {
                let updated = try await appState.api.toggleGroceryItem(id: item.id, checked: nextChecked)
                guard isCurrent(context, in: appState) else { return }
                updateLocalItem(item.id) { $0 = updated }
            }
            await appState.refreshDashboard()
        } catch {
            guard isCurrent(context, in: appState) else { return }
            updateLocalItem(item.id) { $0 = item }
            report(error, in: appState)
        }
    }

    func delete(_ item: GroceryItem) async {
        guard let appState, let context = beginWrite(appState) else { return }
        defer { isWorking = false }
        let previous = items
        items.removeAll { $0.id == item.id }
        do {
            if context.native {
                try appState.nativeReminders.deleteItem(itemId: item.id)
                appState.nativeGroceryItems = items
            } else {
                try await appState.api.deleteGroceryItem(id: item.id)
            }
            guard isCurrent(context, in: appState) else { return }
            await appState.refreshDashboard()
        } catch {
            guard isCurrent(context, in: appState) else { return }
            items = previous
            report(error, in: appState)
        }
    }

    func clearChecked() async {
        guard let appState, let context = beginWrite(appState) else { return }
        defer { isWorking = false }
        let previous = items
        items.removeAll { $0.checked }
        do {
            if context.native {
                for item in previous where item.checked { try appState.nativeReminders.deleteItem(itemId: item.id) }
                appState.nativeGroceryItems = items
            } else {
                try await appState.api.clearCheckedGroceryItems()
            }
            guard isCurrent(context, in: appState) else { return }
            await appState.refreshDashboard()
        } catch {
            guard isCurrent(context, in: appState) else { return }
            // Native deletes commit individually; reconcile any partial success rather than restore phantom items.
            if context.native, let fetched = try? await appState.nativeReminders.loadItems(), isCurrent(context, in: appState) {
                items = fetched
                appState.nativeGroceryItems = fetched
            } else if isCurrent(context, in: appState) {
                items = previous
            }
            report(error, in: appState)
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
