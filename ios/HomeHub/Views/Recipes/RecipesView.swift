import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = RecipesViewModel()
    @State private var activeRecipeSheet: RecipeSheetPresentation?
    /// A recipe opened from the list when the page is too narrow for the detail panel beside it.
    @State private var narrowDetailId: String?

    /// The detail panel sits beside the list only when the page is wide enough to leave the list about
    /// 300pt. Size class alone isn't enough: an iPad mini in portrait is "regular" but only about 590pt
    /// wide, where a fixed 360pt panel squeezed the title and the Add Recipe button onto several lines.
    private static let detailPanelMinimumWidth: CGFloat = 680

    var body: some View {
        GeometryReader { proxy in
            content(wideEnoughForPanel: proxy.size.width >= Self.detailPanelMinimumWidth)
        }
        .sheet(item: $activeRecipeSheet) { sheet in
            RecipeManagementSheet(sheet: sheet, recipes: viewModel.recipes, viewModel: viewModel)
        }
        .sheet(isPresented: Binding(get: { narrowDetailId != nil }, set: { if !$0 { narrowDetailId = nil } })) {
            if let id = narrowDetailId, let recipe = viewModel.recipes.first(where: { $0.id == id }) {
                RecipeDetailPanel(recipe: recipe, viewModel: viewModel) {
                    // One sheet at a time: close this one, then open the editor.
                    narrowDetailId = nil
                    activeRecipeSheet = .edit(recipe.id)
                }
                .padding(.top, 8)
                .presentationDetents([.large])
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func content(wideEnoughForPanel: Bool) -> some View {
        Group {
            if horizontalSizeClass == .compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if let error = viewModel.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        if let success = viewModel.successMessage {
                            Text(success).font(.footnote.weight(.semibold)).foregroundStyle(HubTheme.accentText)
                        }
                        recipesGrid(columns: [GridItem(.flexible())])
                    }
                }
                .navigationDestination(for: RecipeRoute.self) { route in
                    recipeViewer(id: route.id)
                }
            } else if wideEnoughForPanel {
                wideContent
            } else {
                narrowContent
            }
        }
    }

    /// A regular-width page that is too narrow for the panel: the list takes the whole width and a
    /// recipe opens in a sheet.
    private var narrowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                if let success = viewModel.successMessage {
                    Text(success).font(.footnote.weight(.semibold)).foregroundStyle(HubTheme.accentText)
                }
                recipesGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)], opensSheet: true)
            }
        }
    }

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if let success = viewModel.successMessage {
                        Text(success).font(.footnote.weight(.semibold)).foregroundStyle(HubTheme.accentText)
                    }
                    if viewModel.isLoading && viewModel.recipes.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    } else if viewModel.recipes.isEmpty {
                        EmptyStateView(text: "Save your first recipe manually or import one from a website.")
                    } else {
                        recipesGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16, alignment: .top)])
                    }
                }
            }
            .frame(maxWidth: .infinity)

            recipeDetailPanel
                .frame(width: 360)
        }
    }

    /// Tags in use across the household's recipes. Pick several to narrow down (Dinner + Chicken).
    @ViewBuilder
    private var tagFilterBar: some View {
        if !viewModel.availableTags.isEmpty {
            TagFlowLayout(spacing: 8) {
                ForEach(viewModel.availableTags, id: \.self) { tag in
                    TagChip(text: tag, isSelected: RecipeTagHelpers.contains(viewModel.tagFilters, tag)) {
                        viewModel.toggleTagFilter(tag)
                    }
                }
                if !viewModel.tagFilters.isEmpty {
                    ClearFiltersChip { viewModel.clearTagFilters() }
                }
            }
        }
    }

    @ViewBuilder
    private func recipesGrid(columns: [GridItem], opensSheet: Bool = false) -> some View {
        if viewModel.isLoading && viewModel.recipes.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        } else if viewModel.recipes.isEmpty {
            EmptyStateView(text: "Save your first recipe manually or import one from a website.")
        } else {
            tagFilterBar
            if viewModel.filteredRecipes.isEmpty {
                VStack(spacing: 10) {
                    EmptyStateView(text: "No recipes have all of those tags.")
                    Button("Clear Filters") { viewModel.clearTagFilters() }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                }
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredRecipes) { recipe in
                    if horizontalSizeClass == .compact {
                        NavigationLink(value: RecipeRoute(id: recipe.id)) {
                            RecipeCard(recipe: recipe, isSelected: false)
                        }
                        .buttonStyle(.plain)
                    } else {
                        RecipeCard(recipe: recipe, isSelected: !opensSheet && viewModel.selectedRecipeId == recipe.id) {
                            viewModel.selectedRecipeId = recipe.id
                            if opensSheet { narrowDetailId = recipe.id }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recipeViewer(id: String) -> some View {
        if let recipe = viewModel.recipes.first(where: { $0.id == id }) {
            RecipeDetailPanel(recipe: recipe, viewModel: viewModel) {
                activeRecipeSheet = .edit(recipe.id)
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView(
                "Recipe Missing",
                systemImage: "fork.knife.circle",
                description: Text("This recipe could not be found.")
            )
        }
    }

    @ViewBuilder
    private var recipeDetailPanel: some View {
        if let recipe = viewModel.selectedRecipe {
            RecipeDetailPanel(recipe: recipe, viewModel: viewModel) {
                activeRecipeSheet = .edit(recipe.id)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        } else if !viewModel.isLoading {
            HubCard {
                Text("Select a recipe to view details.")
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if horizontalSizeClass != .compact || viewModel.canManage {
            HStack(alignment: .bottom) {
                if horizontalSizeClass != .compact {
                    Text("Recipes")
                        .font(HubTheme.pageTitle)
                }
                Spacer()
                if viewModel.canManage {
                    Menu {
                        Button {
                            activeRecipeSheet = .add(UUID())
                        } label: {
                            Label("Add Manually", systemImage: "plus")
                        }
                        Button {
                            activeRecipeSheet = .importRecipe(UUID())
                        } label: {
                            Label("Import from URL", systemImage: "arrow.down.circle")
                        }
                        Button {
                            activeRecipeSheet = .importCrouton(UUID())
                        } label: {
                            Label("Import from Crouton", systemImage: "square.and.arrow.down.on.square")
                        }
                    } label: {
                        Label("Add Recipe", systemImage: "plus")
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .primary))
                }
            }
        }
    }
}

private struct RecipeRoute: Hashable {
    let id: String
}

private struct RecipeCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let recipe: Recipe
    var isSelected = false
    var onSelect: (() -> Void)?

    var body: some View {
        Group {
            if let onSelect {
                Button(action: onSelect) { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
    }

    /// A phone card is nearly the screen wide; on iPad it is one grid column.
    private var imagePixelSize: Int {
        horizontalSizeClass == .compact ? 1100 : 700
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
                if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                    RemoteImage(url: url, maxPixelSize: imagePixelSize) {
                        placeholderImage
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
                        Text("\(RecipeLines.items(recipe.ingredients).count) ingredients")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    if !recipe.tags.isEmpty {
                        TagFlowLayout(spacing: 6) {
                            ForEach(recipe.tags.prefix(4), id: \.self) { tag in
                                TagPill(text: tag)
                            }
                        }
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

    private var placeholderImage: some View {
        ZStack {
            HubTheme.sunSoft.opacity(0.6)
            Text("No photo")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
        }
    }
}

/// A group heading inside a recipe's ingredients or directions ("For the gravy", "Stove").
private struct RecipeSectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(HubTheme.accentText)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct RecipeDetailPanel: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let recipe: Recipe
    @ObservedObject var viewModel: RecipesViewModel
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HubCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                            RemoteImage(url: url, maxPixelSize: 1100) {
                                Color.clear
                            }
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Text(recipe.title)
                            .font(.title.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let description = recipe.description, !description.isEmpty {
                            Text(description)
                                .foregroundStyle(HubTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
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

                        if !recipe.tags.isEmpty {
                            TagFlowLayout(spacing: 6) {
                                ForEach(recipe.tags, id: \.self) { tag in
                                    TagPill(text: tag)
                                }
                            }
                        }

                        if !recipe.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ingredients").font(.headline)
                                Button {
                                    Task { await viewModel.addIngredientsToGroceryList(recipe) }
                                } label: {
                                    Label("Add to List", systemImage: "cart.badge.plus")
                                }
                                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                                .disabled(viewModel.isWorking)
                            }
                            ForEach(Array(RecipeLines.display(recipe.ingredients).enumerated()), id: \.offset) { _, line in
                                switch line {
                                case .heading(let text):
                                    RecipeSectionHeading(text: text)
                                case .item(_, let text):
                                    Text("• \(text)")
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 4)
                                }
                            }
                        }

                        if !recipe.directions.isEmpty {
                            Text("Directions").font(.headline)
                            ForEach(Array(RecipeLines.display(recipe.directions).enumerated()), id: \.offset) { _, line in
                                switch line {
                                case .heading(let text):
                                    RecipeSectionHeading(text: text)
                                case .item(let number, let text):
                                    Text("\(number). \(text)")
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 4)
                                }
                            }
                        }

                        if let nutrition = recipe.nutrition, !nutrition.isEmpty {
                            Text("Nutrition").font(.headline)
                            ForEach(nutrition.keys.sorted(), id: \.self) { key in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(key).font(.subheadline.weight(.bold))
                                    Spacer(minLength: 8)
                                    Text(nutrition[key] ?? "")
                                        .foregroundStyle(HubTheme.muted)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }

                        if let notes = recipe.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes").font(.headline)
                                Text(notes)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.canManage {
                    Button(action: onEdit) {
                        Label("Edit Recipe", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalSizeClass == .compact ? 16 : 0)
            .padding(.vertical, horizontalSizeClass == .compact ? 14 : 0)
        }
        .contextMenu {
            if viewModel.canManage {
                Button(action: onEdit) {
                    Label("Edit Recipe", systemImage: "pencil")
                }
            }
        }
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

private enum RecipeSheetPresentation: Identifiable {
    case add(UUID)
    case edit(String)
    case importRecipe(UUID)
    case importCrouton(UUID)

    var id: String {
        switch self {
        case .add(let id):
            "add-\(id.uuidString)"
        case .edit(let recipeId):
            "edit-\(recipeId)"
        case .importRecipe(let id):
            "import-\(id.uuidString)"
        case .importCrouton(let id):
            "crouton-\(id.uuidString)"
        }
    }
}

private struct RecipeManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sheet: RecipeSheetPresentation
    let recipes: [Recipe]
    @ObservedObject var viewModel: RecipesViewModel

    private var recipe: Recipe? {
        guard case .edit(let recipeId) = sheet else { return nil }
        return recipes.first { $0.id == recipeId }
    }

    private var title: String {
        switch sheet {
        case .add:
            "Add Recipe"
        case .edit:
            "Edit Recipe"
        case .importRecipe:
            "Import Recipe"
        case .importCrouton:
            "Import from Crouton"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch sheet {
                    case .add:
                        RecipeFormView(
                            submitLabel: "Save Recipe",
                            onSubmit: { input in
                                let saved = await viewModel.addRecipe(input)
                                if saved {
                                    dismiss()
                                }
                                return saved
                            },
                            onSuggestTags: { title, ingredients in
                                await viewModel.suggestTags(title: title, ingredients: ingredients)
                            }
                        )
                    case .edit:
                        if let recipe {
                            RecipeFormView(
                                recipe: recipe,
                                submitLabel: "Save Changes",
                                onSubmit: { input in
                                    let saved = await viewModel.updateRecipe(id: recipe.id, input: input)
                                    if saved {
                                        dismiss()
                                    }
                                    return saved
                                },
                                onSuggestTags: { title, ingredients in
                                    await viewModel.suggestTags(title: title, ingredients: ingredients)
                                }
                            )
                        } else {
                            ContentUnavailableView(
                                "Recipe Missing",
                                systemImage: "fork.knife.circle",
                                description: Text("This recipe could not be found.")
                            )
                        }
                    case .importRecipe:
                        RecipeImportForm(viewModel: viewModel) {
                            dismiss()
                        }
                    case .importCrouton:
                        CroutonImportView {
                            await viewModel.load()
                        }
                    }
                }
                .padding()
                // Room to scroll past the delete button pinned over the corner.
                .padding(.bottom, recipe == nil ? 0 : 72)
            }
            .background(HubTheme.canvas)
            .cornerDeleteButton(
                isShown: recipe != nil,
                accessibilityLabel: "Delete recipe",
                confirmTitle: "Delete \(recipe?.title ?? "this recipe")?",
                confirmButton: "Delete Recipe",
                message: "This removes the recipe for everyone."
            ) {
                guard let recipe else { return }
                if await viewModel.deleteRecipe(id: recipe.id) {
                    dismiss()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RecipeImportForm: View {
    @ObservedObject var viewModel: RecipesViewModel
    let onImported: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a recipe URL. Beacon will pull ingredients, directions, times, and nutrition from structured page data.")
                .font(.footnote)
                .foregroundStyle(HubTheme.muted)

            TextField("https://example.com/recipe", text: $viewModel.importURL)
                .textFieldStyle(HubFieldStyle())
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit {
                    Task { await importRecipe() }
                }

            Button {
                Task { await importRecipe() }
            } label: {
                Label("Import Recipe", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(viewModel.isWorking || viewModel.importURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func importRecipe() async {
        let imported = await viewModel.importRecipe()
        if imported {
            onImported()
        }
    }
}
