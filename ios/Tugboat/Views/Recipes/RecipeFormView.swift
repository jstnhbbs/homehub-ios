import SwiftUI

struct RecipeFormView: View {
    var recipe: Recipe?
    let submitLabel: String
    var editorSession: EditorSession? = nil
    var onSubmit: (RecipeInput) async -> Bool
    var onSuggestTags: ((String, [String]) async -> [String])?

    @State private var title = ""
    @State private var description = ""
    @State private var servings = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var totalTime = ""
    @State private var ingredientLines: [EditableRecipeLine] = []
    @State private var directionLines: [EditableRecipeLine] = []
    @State private var nutritionText = ""
    @State private var sourceUrl = ""
    @State private var imageUrl = ""
    @State private var notes = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isSuggestingTags = false
    @State private var isSaving = false
    @State private var initialDraft: Draft?

    private struct Draft: Equatable {
        var text: [String]
        var ingredients: [String]
        var directions: [String]
        var tags: [String]
    }

    private var draft: Draft {
        Draft(text: [title, description, servings, prepTime, cookTime, totalTime,
                     nutritionText, sourceUrl, imageUrl, notes, newTag],
              ingredients: EditableRecipeLine.stored(ingredientLines),
              directions: EditableRecipeLine.stored(directionLines),
              tags: tags)
    }

    private var ingredientsText: String { EditableRecipeLine.stored(ingredientLines).joined(separator: "\n") }
    private var directionsText: String { EditableRecipeLine.stored(directionLines).joined(separator: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            group {
                valueRow("Name", text: $title, placeholder: "Recipe title")
            }

            group {
                valueRow("Servings", text: $servings, placeholder: "4")
                Divider().overlay(HubTheme.line)
                valueRow("Prep Time", text: $prepTime, placeholder: "15 min")
                Divider().overlay(HubTheme.line)
                valueRow("Cook Time", text: $cookTime, placeholder: "30 min")
                Divider().overlay(HubTheme.line)
                valueRow("Total Time", text: $totalTime, placeholder: "45 min")
            }

            section("Description") {
                group {
                    TextField("Short description (optional)", text: $description, axis: .vertical)
                        .accessibilityLabel("Description")
                        .lineLimit(2...4)
                        .padding(.vertical, 12)
                }
            }

            section("Ingredients") {
                RecipeLineListEditor(kind: .ingredients, lines: $ingredientLines)
            }

            section("Method") {
                RecipeLineListEditor(kind: .method, lines: $directionLines)
            }

            section("Notes") {
                group {
                    TextField("Add Note", text: $notes, axis: .vertical)
                        .accessibilityLabel("Family Notes")
                        .lineLimit(2...6)
                        .padding(.vertical, 12)
                }
            }

            section("Nutrition") {
                group {
                    TextField("Calories: 420", text: $nutritionText, axis: .vertical)
                        .accessibilityLabel("Nutrition")
                        .lineLimit(2...10)
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 12)
                }
            }

            section("Photo") {
                group {
                    valueRow("Image URL", text: $imageUrl, placeholder: "Optional", isURL: true)
                }
            }

            section("Website") {
                group {
                    valueRow("Source URL", text: $sourceUrl, placeholder: "Optional", isURL: true)
                }
            }

            section("Tags") {
                group {
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
                                .accessibilityLabel("New Tag")
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
                    .padding(.vertical, 12)
                }
            }

            Button(submitLabel) {
                Task {
                    guard !isSaving, !isSuggestingTags else { return }
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
                    if let editorSession, !editorSession.beginOperation() { return }
                    isSaving = true
                    defer { isSaving = false; editorSession?.endOperation() }
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || isSuggestingTags || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .disabled(isSaving)
        .onAppear {
            guard initialDraft == nil else { return }
            populate()
            initialDraft = draft
        }
        .onChange(of: recipe?.id) { _, _ in
            populate()
            initialDraft = draft
            editorSession?.updateChanges(false)
        }
        .onChange(of: draft) { _, newValue in
            if let initialDraft { editorSession?.updateChanges(newValue != initialDraft) }
        }
    }

    private func populate() {
        guard let recipe else { return }
        title = recipe.title
        description = recipe.description ?? ""
        servings = recipe.servings ?? ""
        prepTime = recipe.prepTime ?? ""
        cookTime = recipe.cookTime ?? ""
        totalTime = recipe.totalTime ?? ""
        ingredientLines = EditableRecipeLine.lines(from: recipe.ingredients)
        directionLines = EditableRecipeLine.lines(from: recipe.directions)
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

    // MARK: Layout pieces

    /// A named group of cards, with its title above it like the sections of a Settings list.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A label on the left and the value, in the accent color, on the right.
    private func valueRow(_ label: String, text: Binding<String>, placeholder: String, isURL: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
            TextField(placeholder, text: text)
                .accessibilityLabel(label)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(HubTheme.accentText)
                .textInputAutocapitalization(isURL ? .never : .sentences)
                .keyboardType(isURL ? .URL : .default)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
    }
}
