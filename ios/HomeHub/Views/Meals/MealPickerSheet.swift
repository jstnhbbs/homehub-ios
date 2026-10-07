import SwiftUI

/// Picks what goes in one slot: a recently used meal, a saved recipe, or anything typed in.
/// Choosing a recipe or recent meal saves immediately; typed meals save with Save.
struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MealsViewModel
    let ref: MealSlotRef

    @State private var title: String
    @State private var recipeId: String?
    @State private var search = ""

    init(viewModel: MealsViewModel, ref: MealSlotRef) {
        self.viewModel = viewModel
        self.ref = ref
        let current = viewModel.meal(ref)
        _title = State(initialValue: current?.title ?? "")
        _recipeId = State(initialValue: current?.recipeId)
    }

    private var current: Meal? {
        viewModel.meal(ref)
    }

    private var trimmedTitle: String {
        MealPlanHelpers.normalizedTitle(title)
    }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredRecents: [RecentMeal] {
        guard !query.isEmpty else { return viewModel.recentMeals }
        return viewModel.recentMeals.filter { $0.title.lowercased().contains(query) }
    }

    /// Search matches a recipe's name or any of its tags ("chicken", "dinner").
    private var filteredRecipes: [RecipeOption] {
        guard !query.isEmpty else { return viewModel.recipes }
        return viewModel.recipes.filter { recipe in
            recipe.title.lowercased().contains(query) || recipe.tags.contains { $0.lowercased().contains(query) }
        }
    }

    /// The meal-type tag for this slot, such as "Dinner".
    private var slotTag: String? {
        RecipeTagHelpers.mealTag(forSlot: ref.slot.rawValue)
    }

    /// Recipes tagged for this slot come first, so filling a dinner shows dinner recipes on top.
    private var suggestedRecipes: [RecipeOption] {
        guard let slotTag else { return [] }
        return filteredRecipes.filter { RecipeTagHelpers.contains($0.tags, slotTag) }
    }

    private var otherRecipes: [RecipeOption] {
        let suggestedIds = Set(suggestedRecipes.map(\.id))
        return filteredRecipes.filter { !suggestedIds.contains($0.id) }
    }

    private var navigationTitle: String {
        let day = DateHelpers.formatLocalDate(ref.localDate, timezone: viewModel.timezone, pattern: "EEEE")
        return "\(day) \(ref.slot.label)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Meal name. One item per line to add sides", text: $title, axis: .vertical)
                        .lineLimit(1...5)
                        .onChange(of: title) { _, newValue in
                            // Editing the text of a recipe-backed meal makes it a custom meal.
                            if let recipeId,
                               viewModel.recipes.first(where: { $0.id == recipeId })?.title != newValue {
                                self.recipeId = nil
                            }
                        }
                    if recipeId != nil {
                        Label("Linked to a saved recipe", systemImage: "book.closed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HubTheme.accentText)
                    }
                } header: {
                    Text("Meal")
                }

                if !filteredRecents.isEmpty {
                    Section("Recently used") {
                        ForEach(filteredRecents) { recent in
                            choiceRow(title: recent.title, isRecipe: recent.recipeId != nil) {
                                choose(title: recent.title, recipeId: recent.recipeId)
                            }
                        }
                    }
                }

                if !suggestedRecipes.isEmpty, let slotTag {
                    Section("\(slotTag) recipes") {
                        ForEach(suggestedRecipes) { recipe in
                            recipeRow(recipe)
                        }
                    }
                }

                Section(suggestedRecipes.isEmpty ? "Saved recipes" : "Other recipes") {
                    if otherRecipes.isEmpty && suggestedRecipes.isEmpty {
                        Text(viewModel.recipes.isEmpty ? "No saved recipes yet." : "No recipes match your search.")
                            .font(.subheadline)
                            .foregroundStyle(HubTheme.muted)
                    } else {
                        ForEach(otherRecipes) { recipe in
                            recipeRow(recipe)
                        }
                    }
                }

                if current != nil {
                    Section {
                        Button("Clear Meal", role: .destructive) {
                            Task { await viewModel.clearMeal(ref) }
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search recipes and recent meals")
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        choose(title: title, recipeId: recipeId)
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .task { await viewModel.loadRecentMeals() }
        }
        .presentationDetents([.medium, .large])
    }

    private func recipeRow(_ recipe: RecipeOption) -> some View {
        choiceRow(title: recipe.title, isRecipe: true) {
            choose(title: recipe.title, recipeId: recipe.id)
        }
    }

    private func choiceRow(title: String, isRecipe: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isRecipe ? "book.closed" : "fork.knife")
                    .font(.subheadline)
                    .foregroundStyle(HubTheme.accentText)
                    .frame(width: 24)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
    }

    /// Saves in the background so the sheet closes right away; failures show on the plan screen.
    private func choose(title: String, recipeId: String?) {
        let ref = ref
        let viewModel = viewModel
        Task {
            await viewModel.setMeal(localDate: ref.localDate, slot: ref.slot, title: title, recipeId: recipeId)
        }
        dismiss()
    }
}
