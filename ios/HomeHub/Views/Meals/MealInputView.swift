import SwiftUI

struct MealInputView: View {
    let recipes: [RecipeOption]
    let readOnly: Bool
    @Binding var title: String
    @Binding var recipeId: String?
    var onTitleChanged: () -> Void

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
                    onTitleChanged()
                }
            }
        }
    }
}
