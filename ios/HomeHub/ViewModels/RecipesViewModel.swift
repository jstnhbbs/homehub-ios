import Foundation

@MainActor
final class RecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var selectedRecipeId: String?
    @Published var isLoading = false
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showAddForm = false
    @Published var importURL = ""

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var selectedRecipe: Recipe? {
        guard let selectedRecipeId else { return recipes.first }
        return recipes.first { $0.id == selectedRecipeId }
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            recipes = try await appState.api.fetchRecipes()
            if selectedRecipeId == nil {
                selectedRecipeId = recipes.first?.id
            } else if !recipes.contains(where: { $0.id == selectedRecipeId }) {
                selectedRecipeId = recipes.first?.id
            }
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func importRecipe() async -> Bool {
        guard let appState else { return false }
        let url = importURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let recipe = try await appState.api.importRecipe(ImportRecipeRequest(url: url))
            importURL = ""
            await load()
            selectedRecipeId = recipe.id
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func addRecipe(_ input: RecipeInput) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let recipe = try await appState.api.addRecipe(input)
            showAddForm = false
            await load()
            selectedRecipeId = recipe.id
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func updateRecipe(id: String, input: RecipeInput) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let recipe = try await appState.api.updateRecipe(id: id, input: input)
            await load()
            selectedRecipeId = recipe.id
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func deleteRecipe(id: String) async -> Bool {
        guard let appState else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.api.deleteRecipe(id: id)
            selectedRecipeId = nil
            await load()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func addIngredientsToGroceryList(_ recipe: Recipe) async -> Bool {
        guard let appState else { return false }
        let ingredients = recipe.ingredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !ingredients.isEmpty else {
            errorMessage = "This recipe does not have ingredients to add."
            return false
        }

        appState.nativeReminders.refreshAccessStatus()
        guard appState.nativeReminders.hasFullAccess else {
            errorMessage = "Allow Reminders access from Groceries before adding ingredients."
            return false
        }

        isWorking = true
        errorMessage = nil
        successMessage = nil
        defer { isWorking = false }

        do {
            let count = try appState.nativeReminders.addItems(ingredients)
            successMessage = "Added \(count) ingredient\(count == 1 ? "" : "s") to Reminders."
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }
}
