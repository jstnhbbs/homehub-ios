import SwiftUI

struct RecipeFormView: View {
    var recipe: Recipe?
    let submitLabel: String
    var onSubmit: (RecipeInput) async -> Bool
    var onDelete: (() async -> Bool)?

    @State private var title = ""
    @State private var description = ""
    @State private var servings = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var totalTime = ""
    @State private var ingredientsText = ""
    @State private var directionsText = ""
    @State private var nutritionText = ""
    @State private var sourceUrl = ""
    @State private var imageUrl = ""
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Title") {
                TextField("Recipe title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            FormField(label: "Description") {
                TextField("Short description (optional)", text: $description, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                FormField(label: "Servings") {
                    TextField("4", text: $servings).textFieldStyle(.roundedBorder)
                }
                FormField(label: "Total time") {
                    TextField("45 min", text: $totalTime).textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 8) {
                FormField(label: "Prep time") {
                    TextField("15 min", text: $prepTime).textFieldStyle(.roundedBorder)
                }
                FormField(label: "Cook time") {
                    TextField("30 min", text: $cookTime).textFieldStyle(.roundedBorder)
                }
            }

            FormField(label: "Ingredients") {
                TextField("One ingredient per line", text: $ingredientsText, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            FormField(label: "Directions") {
                TextField("One step per line", text: $directionsText, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(.roundedBorder)
            }

            FormField(label: "Nutrition") {
                TextField("Calories: 420", text: $nutritionText, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            FormField(label: "Source URL") {
                TextField("Optional", text: $sourceUrl)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            FormField(label: "Image URL") {
                TextField("Optional", text: $imageUrl)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            FormField(label: "Family notes") {
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            Button(submitLabel) {
                Task {
                    guard let input = RecipeFormHelpers.buildInput(
                        title: title,
                        description: description,
                        servings: servings,
                        prepTime: prepTime,
                        cookTime: cookTime,
                        totalTime: totalTime,
                        ingredientsText: ingredientsText,
                        directionsText: directionsText,
                        nutritionText: nutritionText,
                        sourceUrl: sourceUrl,
                        imageUrl: imageUrl,
                        notes: notes
                    ) else { return }
                    isSaving = true
                    defer { isSaving = false }
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let onDelete {
                Button("Delete recipe", role: .destructive) {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        _ = await onDelete()
                    }
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: populate)
        .onChange(of: recipe?.id) { _, _ in populate() }
    }

    private func populate() {
        guard let recipe else { return }
        title = recipe.title
        description = recipe.description ?? ""
        servings = recipe.servings ?? ""
        prepTime = recipe.prepTime ?? ""
        cookTime = recipe.cookTime ?? ""
        totalTime = recipe.totalTime ?? ""
        ingredientsText = RecipeFormHelpers.ingredientsText(recipe.ingredients)
        directionsText = RecipeFormHelpers.directionsText(recipe.directions)
        nutritionText = RecipeFormHelpers.nutritionText(recipe.nutrition)
        sourceUrl = recipe.sourceUrl ?? ""
        imageUrl = recipe.imageUrl ?? ""
        notes = recipe.notes ?? ""
    }
}
