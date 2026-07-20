import SwiftUI

struct MealInputView: View {
    let localDate: String
    let slot: MealSlot
    let meal: Meal?
    let recipes: [RecipeOption]
    let readOnly: Bool
    var onSave: (String, String?) async -> Bool

    @State private var title: String
    @State private var recipeId: String?
    @State private var isSaving = false

    init(
        localDate: String,
        slot: MealSlot,
        meal: Meal?,
        recipes: [RecipeOption],
        readOnly: Bool,
        onSave: @escaping (String, String?) async -> Bool
    ) {
        self.localDate = localDate
        self.slot = slot
        self.meal = meal
        self.recipes = recipes
        self.readOnly = readOnly
        self.onSave = onSave
        _title = State(initialValue: meal?.title ?? "")
        _recipeId = State(initialValue: meal?.recipeId)
    }

    var body: some View {
        if readOnly {
            readOnlyBody
        } else {
            editableBody
        }
    }

    private var readOnlyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.isEmpty ? "Not planned" : title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(title.isEmpty ? HubTheme.muted : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(HubTheme.tileQuiet)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var editableBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !recipes.isEmpty {
                Picker("Recipe", selection: Binding(
                    get: { recipeId ?? "" },
                    set: { newValue in
                        recipeId = newValue.isEmpty ? nil : newValue
                        if let recipe = recipes.first(where: { $0.id == newValue }) {
                            title = recipe.title
                        }
                    }
                )) {
                    Text("Choose a saved recipe").tag("")
                    ForEach(recipes) { recipe in
                        Text(recipe.title).tag(recipe.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }

            ZStack(alignment: .topTrailing) {
                TextField(
                    "Add meal — one item per line",
                    text: $title,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .onChange(of: title) { _, _ in
                    if recipeId != nil, title != recipes.first(where: { $0.id == recipeId })?.title {
                        recipeId = nil
                    }
                }

                Button {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        _ = await onSave(title, recipeId)
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HubTheme.sage)
                }
                .padding(8)
                .disabled(isSaving)
            }
        }
    }
}
