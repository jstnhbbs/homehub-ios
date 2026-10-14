import Foundation
import WidgetKit

@MainActor
enum WidgetActionRunner {
    static func perform(action: String, itemId: String, userId: String, householdId: String, localDate: String) async throws {
        let store = WidgetStore()
        let credentials = SessionCredentials.shared(for: AppConfig.baseURL)
        let generation = credentials.sessionGeneration
        guard credentials.hasSession, let saved = store.load(), saved.userId == userId,
              saved.householdId == householdId else { throw WidgetActionFailure.openApp }
        let api = TugboatAPI(baseURL: AppConfig.baseURL)
        do {
            let account = try await api.fetchAccount()
            let dashboard = try await api.fetchDashboard()
            guard credentials.sessionGeneration == generation, account.user.id == userId,
                  dashboard.household.id == householdId,
                  store.load()?.userId == userId else { throw WidgetActionFailure.openApp }
            let current = WidgetSnapshotBuilder.make(dashboard: dashboard, userId: account.user.id, palette: "sage",
                events: [], groceries: [], modules: dashboard.hubModules ?? .defaults)
            guard WidgetActionPolicy.allows(action: action, itemId: itemId, userId: userId,
                householdId: householdId, localDate: localDate, current: current) else { throw WidgetActionFailure.stale }
            var endedSleep: NapLog?
            switch action {
            case "step":
                guard dashboard.routineSteps.contains(where: { $0.id == itemId }) else { throw WidgetActionFailure.stale }
                try await api.toggleRoutineStep(.init(stepId: itemId, localDate: dashboard.localDate, completed: true))
            case "chore":
                guard let chore = dashboard.chores.first(where: { $0.id == itemId }) else { throw WidgetActionFailure.stale }
                try await api.toggleChore(.init(choreId: itemId, periodKey: chore.periodKey, completed: true))
            case "endSleep":
                guard dashboard.naps.contains(where: { $0.id == itemId && $0.endedAt == nil }) else { throw WidgetActionFailure.stale }
                endedSleep = try await api.endNap(napId: itemId)
            case "refresh": break
            default: throw WidgetActionFailure.stale
            }
            // A successful write stays successful even if the following read fails. Apply its known
            // result to the snapshot, then reconcile with fresh server data when available.
            var fresh = (try? await api.fetchDashboard()) ?? dashboard
            if action == "step", WidgetActionPolicy.appliesCompletion(action: action, writtenDay: dashboard.localDate, currentDay: fresh.localDate),
               let index = fresh.routineSteps.firstIndex(where: { $0.id == itemId }) { fresh.routineSteps[index].completed = true }
            if action == "chore", let index = fresh.chores.firstIndex(where: { $0.id == itemId }),
               WidgetActionPolicy.appliesCompletion(action: action, writtenDay: dashboard.localDate, currentDay: fresh.localDate,
                    writtenPeriod: dashboard.chores.first { $0.id == itemId }?.periodKey, currentPeriod: fresh.chores[index].periodKey) {
                fresh.chores[index].completed = true
            }
            if let endedSleep {
                fresh.naps.removeAll { $0.id == itemId }
                fresh.naps.append(endedSleep)
            } else if action == "endSleep", fresh.naps.contains(where: { $0.id == itemId && $0.endedAt == nil }) {
                fresh.naps.removeAll { $0.id == itemId }
            }
            guard credentials.sessionGeneration == generation, store.load()?.userId == userId else { return }
            let calendar = NativeCalendarService()
            calendar.refreshAccessStatus()
            let timezone = TimeZone(identifier: fresh.household.timezone) ?? .current
            let start = DateHelpers.gregorian(in: timezone).startOfDay(for: .now)
            let end = DateHelpers.gregorian(in: timezone).date(byAdding: .day, value: 1, to: start) ?? start
            let events = calendar.hasFullAccess ? calendar.scheduleEvents(start: start, end: end) : []
            let reminders = NativeRemindersService()
            reminders.refreshAccessStatus()
            let groceries = reminders.accessStatus == .authorized ? ((try? await reminders.loadItems()) ?? []) : fresh.groceryItems
            guard credentials.sessionGeneration == generation, store.load()?.userId == userId else { return }
            let palette = UserDefaults.standard.string(forKey: "tugboat.accentPalette") ?? "sage"
            let snapshot = WidgetSnapshotBuilder.make(dashboard: fresh, userId: userId, palette: palette,
                events: events, groceries: groceries, modules: fresh.hubModules ?? .defaults)
            _ = store.save(snapshot, force: true)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .tugboatDataChanged, object: nil)
        } catch {
            if case APIError.unauthorized = error, credentials.sessionGeneration == generation {
                credentials.clear()
                store.clear()
                WidgetCenter.shared.reloadAllTimelines()
                NotificationCenter.default.post(name: .tugboatDataChanged, object: nil)
                throw WidgetActionFailure.openApp
            }
            if credentials.sessionGeneration == generation, var snapshot = store.load(), snapshot.userId == userId {
                snapshot.actionError = (error as? WidgetActionFailure)?.localizedDescription ?? WidgetActionFailure.failed.localizedDescription
                _ = store.save(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
            }
            throw error
        }
    }
}
