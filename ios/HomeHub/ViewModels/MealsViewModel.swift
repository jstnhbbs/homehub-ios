import Foundation

@MainActor
final class MealsViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var recipes: [RecipeOption] = []
    @Published var drafts: [String: MealDraft] = [:]
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var groceryPreview: MealGroceryPreview?

    private var appState: AppState?
    private var originalDrafts: [String: MealDraft] = [:]
    private var recipeDetails: [String: Recipe] = [:]

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
            let fetchedRecipes = try await recipesTask
            recipeDetails = Dictionary(
                fetchedRecipes.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            recipes = fetchedRecipes.map(\.asOption)
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

    /// Builds the "add to groceries" preview from the meals still ahead this week (today onward).
    /// Uses the on-screen plan, so unsaved edits are included.
    func prepareGroceryPreview() async {
        guard let appState else { return }
        errorMessage = nil
        successMessage = nil

        let today = DateHelpers.localDateIn(timezone: timezone)
        var entries: [(source: String, ingredient: String)] = []
        var mealsWithoutRecipe: [String] = []

        for localDate in weekDateStrings where localDate >= today {
            for slot in MealSlot.planningSlots {
                let draft = mealDraft(localDate: localDate, slot: slot)
                let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if let recipeId = draft.recipeId, let recipe = recipeDetails[recipeId] {
                    for ingredient in recipe.ingredients {
                        entries.append((source: recipe.title, ingredient: ingredient))
                    }
                } else if !title.isEmpty, !mealsWithoutRecipe.contains(title) {
                    mealsWithoutRecipe.append(title)
                }
            }
        }

        let merged = IngredientMerge.merge(entries)
        guard !merged.isEmpty else {
            errorMessage = mealsWithoutRecipe.isEmpty
                ? "Nothing planned for the rest of this week."
                : "None of the meals left this week use a saved recipe, so there are no ingredients to add."
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            appState.nativeReminders.refreshAccessStatus()
            let usesReminders = appState.nativeReminders.hasFullAccess
            let existing = usesReminders
                ? try await appState.nativeReminders.loadItems()
                : try await appState.api.fetchGroceryItems()
            let onList = Set(existing.filter { !$0.checked }.map { IngredientMerge.matchKey(forTitle: $0.title) })

            groceryPreview = MealGroceryPreview(
                rows: merged.map { item in
                    MealGroceryRow(
                        id: item.id,
                        text: item.displayText,
                        sources: item.sources,
                        alreadyOnList: onList.contains(item.key),
                        isStaple: IngredientMerge.isCommonStaple(key: item.key)
                    )
                },
                mealsWithoutRecipe: mealsWithoutRecipe,
                usesReminders: usesReminders
            )
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func addToGroceries(_ titles: [String]) async -> Bool {
        guard let appState, !titles.isEmpty else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            appState.nativeReminders.refreshAccessStatus()
            if appState.nativeReminders.hasFullAccess {
                _ = try appState.nativeReminders.addItems(titles)
                await appState.refreshNativeGroceryItems()
            } else {
                for title in titles {
                    _ = try await appState.api.addGroceryItem(GroceryItemInput(title: title, category: nil))
                }
            }
            await appState.refreshDashboard()
            successMessage = "Added \(titles.count) item\(titles.count == 1 ? "" : "s") to groceries."
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
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

struct MealGroceryRow: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let sources: [String]
    let alreadyOnList: Bool
    let isStaple: Bool

    /// Already-listed items and pantry staples start unchecked.
    var startsSelected: Bool { !alreadyOnList && !isStaple }
}

struct MealGroceryPreview: Identifiable, Sendable {
    let id = UUID()
    let rows: [MealGroceryRow]
    let mealsWithoutRecipe: [String]
    let usesReminders: Bool
}

private extension MealSlot {
    static let planningSlots: [MealSlot] = [.breakfast, .lunch, .dinner]
}
