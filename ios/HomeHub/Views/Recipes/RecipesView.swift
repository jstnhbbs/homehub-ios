import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RecipesViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if viewModel.isLoading && viewModel.recipes.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    } else if viewModel.recipes.isEmpty {
                        EmptyStateView(text: "Save your first recipe manually or import one from a website.")
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.recipes) { recipe in
                                RecipeCard(recipe: recipe, isSelected: viewModel.selectedRecipeId == recipe.id) {
                                    viewModel.selectedRecipeId = recipe.id
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                if let recipe = viewModel.selectedRecipe {
                    RecipeDetailPanel(recipe: recipe, viewModel: viewModel)
                } else if !viewModel.isLoading {
                    HubCard {
                        Text("Select a recipe to view details.")
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                if viewModel.canManage {
                    importPanel
                    addPanel
                }
            }
            .frame(width: 360)
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Family favorites")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(HubTheme.sage)
            Text("Recipes")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
        }
    }

    private var importPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Import recipe", systemImage: "arrow.down.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                Text("Paste a recipe URL. We pull ingredients, directions, times, and nutrition from structured page data.")
                    .font(.footnote)
                    .foregroundStyle(HubTheme.muted)
                TextField("https://example.com/recipe", text: $viewModel.importURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("Import recipe") {
                    Task { _ = await viewModel.importRecipe() }
                }
                .buttonStyle(.borderedProminent)
                .tint(HubTheme.sage)
                .disabled(viewModel.isWorking || viewModel.importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var addPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Add manually", systemImage: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                RecipeFormView(submitLabel: "Save recipe") { input in
                    await viewModel.addRecipe(input)
                }
            }
        }
    }
}

private struct RecipeCard: View {
    let recipe: Recipe
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholderImage
                        }
                    }
                    .frame(height: 140)
                    .clipped()
                } else {
                    placeholderImage
                        .frame(height: 140)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let description = recipe.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        if let servings = recipe.servings {
                            Text(servings).font(.caption2.weight(.bold)).foregroundStyle(HubTheme.muted)
                        }
                        if let totalTime = recipe.totalTime {
                            Text(totalTime).font(.caption2.weight(.bold)).foregroundStyle(HubTheme.muted)
                        }
                        Text("\(recipe.ingredients.count) ingredients")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                }
                .padding(14)
            }
            .background(HubTheme.tileQuiet)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? HubTheme.sage : HubTheme.line, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        ZStack {
            HubTheme.sunSoft.opacity(0.6)
            Text("No photo")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
        }
    }
}

private struct RecipeDetailPanel: View {
    let recipe: Recipe
    @ObservedObject var viewModel: RecipesViewModel
    @State private var showEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        }
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(recipe.title)
                    .font(.title.weight(.semibold))
                if let description = recipe.description, !description.isEmpty {
                    Text(description).foregroundStyle(HubTheme.muted)
                }

                HStack(spacing: 8) {
                    if let servings = recipe.servings {
                        metaChip(servings, icon: "person.2")
                    }
                    if let prepTime = recipe.prepTime {
                        metaChip("Prep \(prepTime)", icon: "clock")
                    }
                    if let cookTime = recipe.cookTime {
                        metaChip("Cook \(cookTime)", icon: "clock")
                    }
                    if let totalTime = recipe.totalTime {
                        metaChip("Total \(totalTime)", icon: "clock")
                    }
                }

                if !recipe.ingredients.isEmpty {
                    Text("Ingredients").font(.headline)
                    ForEach(recipe.ingredients, id: \.self) { item in
                        Text("• \(item)")
                            .padding(.vertical, 4)
                    }
                }

                if !recipe.directions.isEmpty {
                    Text("Directions").font(.headline)
                    ForEach(Array(recipe.directions.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                            .padding(.vertical, 4)
                    }
                }

                if let nutrition = recipe.nutrition, !nutrition.isEmpty {
                    Text("Nutrition").font(.headline)
                    ForEach(nutrition.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(key).font(.subheadline.weight(.bold))
                            Spacer()
                            Text(nutrition[key] ?? "")
                                .foregroundStyle(HubTheme.muted)
                        }
                    }
                }

                if let notes = recipe.notes, !notes.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes").font(.headline)
                            Text(notes)
                        }
                    }
                }

                if viewModel.canManage {
                    DisclosureGroup("Edit recipe", isExpanded: $showEditForm) {
                        RecipeFormView(
                            recipe: recipe,
                            submitLabel: "Save changes",
                            onSubmit: { input in
                                await viewModel.updateRecipe(id: recipe.id, input: input)
                            },
                            onDelete: {
                                await viewModel.deleteRecipe(id: recipe.id)
                            }
                        )
                        .padding(.top, 8)
                    }
                    .font(.subheadline.weight(.bold))
                }
            }
        }
        .frame(maxHeight: 520)
    }

    private func metaChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HubTheme.tileQuiet)
            .clipShape(Capsule())
    }
}
