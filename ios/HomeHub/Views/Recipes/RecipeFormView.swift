import SwiftUI

struct RecipeFormView: View {
    var recipe: Recipe?
    let submitLabel: String
    var onSubmit: (RecipeInput) async -> Bool
    var onSuggestTags: ((String, [String]) async -> [String])?

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
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isSuggestingTags = false
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormField(label: "Title") {
                TextField("Recipe title", text: $title)
                    .textFieldStyle(HubFieldStyle())
            }

            FormField(label: "Description") {
                TextField("Short description (optional)", text: $description, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(HubFieldStyle())
            }

            HStack(spacing: 8) {
                FormField(label: "Servings") {
                    TextField("4", text: $servings).textFieldStyle(HubFieldStyle())
                }
                FormField(label: "Total Time") {
                    TextField("45 min", text: $totalTime).textFieldStyle(HubFieldStyle())
                }
            }

            HStack(spacing: 8) {
                FormField(label: "Prep Time") {
                    TextField("15 min", text: $prepTime).textFieldStyle(HubFieldStyle())
                }
                FormField(label: "Cook Time") {
                    TextField("30 min", text: $cookTime).textFieldStyle(HubFieldStyle())
                }
            }

            FormField(label: "Ingredients") {
                TextField("One ingredient per line", text: $ingredientsText, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(HubFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }

            FormField(label: "Directions") {
                TextField("One step per line", text: $directionsText, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(HubFieldStyle())
            }

            FormField(label: "Nutrition") {
                TextField("Calories: 420", text: $nutritionText, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(HubFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }

            FormField(label: "Source URL") {
                TextField("Optional", text: $sourceUrl)
                    .textFieldStyle(HubFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            FormField(label: "Image URL") {
                TextField("Optional", text: $imageUrl)
                    .textFieldStyle(HubFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            FormField(label: "Tags") {
                VStack(alignment: .leading, spacing: 10) {
                    TagFlowLayout(spacing: 8) {
                        ForEach(tagChoices, id: \.self) { tag in
                            TagChip(text: tag, isSelected: RecipeTagHelpers.contains(tags, tag)) {
                                tags = RecipeTagHelpers.toggling(tag, in: tags)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Add your own tag", text: $newTag)
                            .textFieldStyle(HubFieldStyle())
                            .submitLabel(.done)
                            .onSubmit(addNewTag)
                        Button("Add", action: addNewTag)
                            .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if onSuggestTags != nil {
                        Button {
                            Task { await suggestTags() }
                        } label: {
                            Label(isSuggestingTags ? "Looking" : "Suggest from ingredients", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                        .disabled(isSuggestingTags || ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            FormField(label: "Family Notes") {
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(HubFieldStyle())
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
                        notes: notes,
                        tags: tags
                    ) else { return }
                    isSaving = true
                    defer { isSaving = false }
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        tags = recipe.tags
    }

    /// The presets, then any custom tags this recipe already has.
    private var tagChoices: [String] {
        RecipeTagHelpers.presets + tags.filter { tag in
            !RecipeTagHelpers.presets.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
    }

    private func addNewTag() {
        tags = RecipeTagHelpers.adding(newTag, to: tags)
        newTag = ""
    }

    private func suggestTags() async {
        guard let onSuggestTags else { return }
        isSuggestingTags = true
        defer { isSuggestingTags = false }
        let suggested = await onSuggestTags(title, RecipeFormHelpers.parseLines(ingredientsText))
        for tag in suggested {
            tags = RecipeTagHelpers.adding(tag, to: tags)
        }
    }
}
