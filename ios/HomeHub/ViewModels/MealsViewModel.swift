import Foundation

@MainActor
final class MealsViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var recipes: [RecipeOption] = []
    @Published var drafts: [String: MealDraft] = [:]
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?

    private var appState: AppState?
    private var originalDrafts: [String: MealDraft] = [:]

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

    var hasUnsavedChanges: Bool {
        for localDate in weekDateStrings {
            for slot in MealSlot.planningSlots {
                let key = draftKey(localDate: localDate, slot: slot)
                if mealDraft(localDate: localDate, slot: slot) != originalDrafts[key, default: .empty] {
                    return true
                }
            }
        }
        return false
    }

    func mealDraft(localDate: String, slot: MealSlot) -> MealDraft {
        let key = draftKey(localDate: localDate, slot: slot)
        if let draft = drafts[key] {
            return draft
        }
        if let meal = meal(localDate: localDate, slot: slot) {
            return MealDraft(title: meal.title, recipeId: meal.recipeId)
        }
        return .empty
    }

    func updateDraftTitle(localDate: String, slot: MealSlot, title: String) {
        let key = draftKey(localDate: localDate, slot: slot)
        var draft = mealDraft(localDate: localDate, slot: slot)
        draft.title = title
        drafts[key] = draft
    }

    func updateDraftRecipe(localDate: String, slot: MealSlot, recipeId: String?) {
        let key = draftKey(localDate: localDate, slot: slot)
        var draft = mealDraft(localDate: localDate, slot: slot)
        draft.recipeId = recipeId
        if let recipeId,
           let recipe = recipes.first(where: { $0.id == recipeId }) {
            draft.title = recipe.title
        }
        drafts[key] = draft
    }

    func clearDraftRecipeIfTitleChanged(localDate: String, slot: MealSlot) {
        let draft = mealDraft(localDate: localDate, slot: slot)
        guard let recipeId = draft.recipeId,
              draft.title != recipes.first(where: { $0.id == recipeId })?.title else {
            return
        }
        updateDraftRecipe(localDate: localDate, slot: slot, recipeId: nil)
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
            resetDrafts()
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func saveMealPlan() async -> Bool {
        guard let appState else { return false }
        let changes = weekDateStrings.flatMap { localDate in
            MealSlot.planningSlots.compactMap { slot -> (String, MealSlot, MealDraft)? in
                let key = draftKey(localDate: localDate, slot: slot)
                let draft = mealDraft(localDate: localDate, slot: slot)
                guard draft != originalDrafts[key, default: .empty] else { return nil }
                return (localDate, slot, draft)
            }
        }
        guard !changes.isEmpty else { return true }

        isWorking = true
        defer { isWorking = false }
        do {
            for change in changes {
                try await appState.api.saveMeal(
                    SaveMealRequest(
                        localDate: change.0,
                        slot: change.1,
                        title: change.2.title,
                        recipeId: change.2.recipeId,
                        notes: nil
                    )
                )
            }
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
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
            if let message = error.userFacingMessage {
                errorMessage = message
            }
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
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    private func resetDrafts() {
        var next: [String: MealDraft] = [:]
        for meal in meals {
            next[draftKey(localDate: meal.localDate, slot: meal.slot)] = MealDraft(
                title: meal.title,
                recipeId: meal.recipeId
            )
        }
        drafts = next
        originalDrafts = next
    }

    private func draftKey(localDate: String, slot: MealSlot) -> String {
        "\(localDate)-\(slot.rawValue)"
    }
}

struct MealDraft: Equatable, Sendable {
    var title: String
    var recipeId: String?

    static let empty = MealDraft(title: "", recipeId: nil)
}

private extension MealSlot {
    static let planningSlots: [MealSlot] = [.breakfast, .lunch, .dinner]
}
