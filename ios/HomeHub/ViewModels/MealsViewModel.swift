import Foundation

@MainActor
final class MealsViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var recipes: [RecipeOption] = []
    @Published var recentMeals: [RecentMeal] = []
    @Published private(set) var weekOffset = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var groceryPreview: MealGroceryPreview?
    @Published private(set) var isWorking = false

    private var appState: AppState?
    private var recipeDetails: [String: Recipe] = [:]
    private var saveVersions: [MealSlotRef: Int] = [:]
    private var inFlightSaves = 0
    private var mealRevision = 0
    private var dashboardRefreshTask: Task<Void, Never>?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    // MARK: - Week

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var weekStartsOn: Int {
        appState?.household?.weekStartsOn ?? WeekStart.defaultWeekStartsOn
    }

    var isCurrentWeek: Bool {
        weekOffset == 0
    }

    var todayString: String {
        DateHelpers.localDateIn(timezone: timezone)
    }

    var weekDates: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let anchor = calendar.date(byAdding: .day, value: weekOffset * 7, to: .now) ?? .now
        return DateHelpers.weekDates(from: anchor, timezone: timezone, weekStartsOn: weekStartsOn)
    }

    var weekDateStrings: [String] {
        weekDates.map { DateHelpers.localDateIn(timezone: timezone, date: $0) }
    }

    var weekStart: String {
        weekDateStrings.first ?? todayString
    }

    var weekRangeLabel: String {
        let dates = weekDateStrings
        guard let first = dates.first, let last = dates.last else { return "" }
        return MealPlanHelpers.weekRangeLabel(first: first, last: last, timezone: timezone)
    }

    var weekSubtitle: String? {
        switch weekOffset {
        case 0: "This Week"
        case 1: "Next Week"
        case -1: "Last Week"
        default: nil
        }
    }

    func changeWeek(by delta: Int) async {
        weekOffset += delta
        meals = []
        await load()
    }

    func goToThisWeek() async {
        guard weekOffset != 0 else { return }
        weekOffset = 0
        meals = []
        await load()
    }

    func meal(localDate: String, slot: MealSlot) -> Meal? {
        meals.first { $0.localDate == localDate && $0.slot == slot }
    }

    func meal(_ ref: MealSlotRef) -> Meal? {
        meal(localDate: ref.localDate, slot: ref.slot)
    }

    // MARK: - Loading

    func load(refreshRecipes: Bool = false) async {
        guard let appState else { return }
        let requestedOffset = weekOffset
        let requestedStart = weekStart
        let requestedRevision = mealRevision
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedMeals = try await appState.api.fetchMeals(weekStart: requestedStart)
            if refreshRecipes || recipeDetails.isEmpty {
                let fetchedRecipes = try await appState.api.fetchRecipes()
                recipeDetails = Dictionary(
                    fetchedRecipes.map { ($0.id, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                recipes = fetchedRecipes.map(\.asOption)
            }
            // Ignore a response for a week the user has already navigated away from, and
            // never overwrite edits that have not been confirmed yet.
            guard requestedOffset == weekOffset, inFlightSaves == 0,
                  requestedRevision == mealRevision else { return }
            meals = fetchedMeals
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    /// Meals from the last few weeks, offered again in the picker.
    func loadRecentMeals() async {
        guard let appState else { return }
        recentMeals = MealPlanHelpers.recentMeals(from: meals)
        var pool = meals
        for weeksBack in 1...2 {
            let start = MealPlanHelpers.date(weekStart, adding: -7 * weeksBack, timezone: timezone)
            if let rows = try? await appState.api.fetchMeals(weekStart: start) {
                pool += rows
            }
        }
        recentMeals = MealPlanHelpers.recentMeals(from: pool)
    }

    // MARK: - Editing (each change saves on its own)

    /// Sets a slot, or clears it when the title is blank. The screen updates immediately and
    /// the change is rolled back if the server rejects it.
    func setMeal(
        localDate: String,
        slot: MealSlot,
        title rawTitle: String,
        recipeId: String? = nil,
        notes: String? = nil
    ) async {
        guard let appState, canManage, !isWorking else { return }
        mealRevision += 1
        let ref = MealSlotRef(localDate: localDate, slot: slot)
        let title = MealPlanHelpers.normalizedTitle(rawTitle)
        let isClearing = title.isEmpty
        let linkedRecipeId = isClearing ? nil : recipeId
        let shownTitle = linkedRecipeId.flatMap { recipeDetails[$0]?.title } ?? title

        let previous = meal(ref)
        let version = (saveVersions[ref] ?? 0) + 1
        saveVersions[ref] = version
        applyLocally(
            ref,
            meal: isClearing
                ? nil
                : Meal(localDate: localDate, slot: slot, title: shownTitle, recipeId: linkedRecipeId, notes: notes)
        )

        inFlightSaves += 1
        defer {
            inFlightSaves -= 1
            mealRevision += 1
        }
        do {
            try await appState.api.saveMeal(
                SaveMealRequest(
                    localDate: localDate,
                    slot: slot,
                    title: title,
                    recipeId: linkedRecipeId,
                    notes: notes
                )
            )
            scheduleDashboardRefresh()
        } catch {
            if saveVersions[ref] == version {
                applyLocally(ref, meal: previous)
            }
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func clearMeal(_ ref: MealSlotRef) async {
        await setMeal(localDate: ref.localDate, slot: ref.slot, title: "")
    }

    /// Dropping a meal on another slot moves it there; if that slot was taken, the two swap.
    func moveMeal(fromToken token: String, to target: MealSlotRef) async {
        guard let appState, canManage, !isWorking, inFlightSaves == 0,
              let source = MealSlotRef(token: token), source != target,
              meal(source) != nil else { return }
        isWorking = true
        mealRevision += 1
        let requestedWeek = weekStart
        inFlightSaves += 1
        errorMessage = nil
        defer {
            isWorking = false
            inFlightSaves -= 1
            mealRevision += 1
            if weekStart != requestedWeek {
                Task { await load() }
            }
        }
        do {
            let response = try await appState.api.moveMeal(
                MoveMealRequest(
                    source: .init(localDate: source.localDate, slot: source.slot),
                    target: .init(localDate: target.localDate, slot: target.slot)
                )
            )
            for ref in [source, target] {
                applyLocally(ref, meal: response.meals.first {
                    $0.localDate == ref.localDate && $0.slot == ref.slot
                })
            }
            scheduleDashboardRefresh()
        } catch {
            if let message = error.userFacingMessage { errorMessage = message }
        }
    }

    /// Copies a meal to the same slot some days later, replacing what is planned there.
    func copyMeal(from ref: MealSlotRef, daysAhead: Int) async {
        guard let source = meal(ref) else { return }
        errorMessage = nil
        let targetDate = MealPlanHelpers.date(ref.localDate, adding: daysAhead, timezone: timezone)
        await setMeal(
            localDate: targetDate,
            slot: ref.slot,
            title: source.title,
            recipeId: source.recipeId,
            notes: source.notes
        )
        guard errorMessage == nil else { return }
        successMessage = daysAhead == 7
            ? "Repeated next week."
            : "Copied to \(DateHelpers.formatLocalDate(targetDate, timezone: timezone, pattern: "EEEE"))."
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

    private func applyLocally(_ ref: MealSlotRef, meal: Meal?) {
        guard weekDateStrings.contains(ref.localDate) else { return }
        meals.removeAll { $0.localDate == ref.localDate && $0.slot == ref.slot }
        if let meal {
            meals.append(meal)
        }
    }

    /// Several quick edits should refresh the dashboard once, not once per edit.
    private func scheduleDashboardRefresh() {
        dashboardRefreshTask?.cancel()
        dashboardRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let self, let appState = self.appState else { return }
            await appState.refreshDashboard()
        }
    }

    // MARK: - Groceries

    /// Builds the "add to groceries" preview from the meals still ahead in the week being shown.
    func prepareGroceryPreview() async {
        guard let appState else { return }
        errorMessage = nil
        successMessage = nil

        let today = todayString
        var entries: [(source: String, ingredient: String)] = []
        var mealsWithoutRecipe: [String] = []

        for localDate in weekDateStrings where localDate >= today {
            for slot in MealSlot.planningSlots {
                guard let planned = meal(localDate: localDate, slot: slot) else { continue }
                let title = planned.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if let recipeId = planned.recipeId, let recipe = recipeDetails[recipeId] {
                    for ingredient in RecipeLines.items(recipe.ingredients) {
                        entries.append((source: recipe.title, ingredient: ingredient))
                    }
                } else if !title.isEmpty, !mealsWithoutRecipe.contains(title) {
                    mealsWithoutRecipe.append(title)
                }
            }
        }

        let merged = IngredientMerge.merge(entries)
        guard !merged.isEmpty else {
            if let last = weekDateStrings.last, last < today {
                errorMessage = "That week has already passed."
            } else if mealsWithoutRecipe.isEmpty {
                errorMessage = isCurrentWeek
                    ? "Nothing planned for the rest of this week."
                    : "Nothing planned for this week."
            } else {
                errorMessage = "None of the planned meals use a saved recipe, so there are no ingredients to add."
            }
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
                heading: isCurrentWeek
                    ? "Ingredients for the rest of this week"
                    : "Ingredients for \(weekRangeLabel)",
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
    let heading: String
    let rows: [MealGroceryRow]
    let mealsWithoutRecipe: [String]
    let usesReminders: Bool
}
