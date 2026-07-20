import Foundation

@MainActor
final class MealsViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var recipes: [RecipeOption] = []
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var weekStartsOn: Int {
        appState?.household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn
    }

    var weekDates: [Date] {
        DateHelpers.weekDates(from: .now, timezone: timezone, weekStartsOn: weekStartsOn)
    }

    var weekDateStrings: [String] {
        weekDates.map { DateHelpers.localDateIn(timezone: timezone, date: $0) }
    }

    var weekStart: String {
        weekDateStrings.first ?? DateHelpers.localDateIn(timezone: timezone)
    }

    func meal(localDate: String, slot: MealSlot) -> Meal? {
        meals.first { $0.localDate == localDate && $0.slot == slot }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let mealsTask = appState.api.fetchMeals(weekStart: weekStart)
            async let recipesTask = appState.api.fetchRecipes()
            meals = try await mealsTask
            recipes = try await recipesTask.map(\.asOption)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveMeal(localDate: String, slot: MealSlot, title: String, recipeId: String?) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await appState.api.saveMeal(
                SaveMealRequest(
                    localDate: localDate,
                    slot: slot,
                    title: title,
                    recipeId: recipeId,
                    notes: nil
                )
            )
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func copyPreviousWeek() async {
        guard let appState else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.api.copyPreviousMealWeek(weekStart: weekStart)
            await load()
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearWeek() async {
        guard let appState else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.api.clearMealWeek(weekStart: weekStart)
            await load()
            await appState.refreshDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
