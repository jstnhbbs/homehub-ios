import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = MealsViewModel()
    @State private var section: FoodHubSection = .week

    private let mealSlots: [MealSlot] = [.breakfast, .lunch, .dinner]

    var body: some View {
        Group {
            if horizontalSizeClass == .compact, section == .week {
                ScrollView {
                    foodContent
                }
            } else {
                foodContent
            }
        }
        .onAppear {
            normalizeSection()
            applyPendingFoodSection()
        }
        .onChange(of: appState.pendingFoodSection) { _, _ in
            applyPendingFoodSection()
        }
        .onChange(of: appState.hubModules) { _, _ in
            normalizeSection()
        }
    }

    private var foodContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if visibleSections.count > 1 {
                sectionPicker
            }

            switch section {
            case .week:
                weekContent
            case .recipes:
                RecipesView()
            case .snacks:
                SnacksView()
            }
        }
    }

    private var visibleSections: [FoodHubSection] {
        [FoodHubSection.week, .snacks, .recipes].filter { $0.isVisible(in: appState.hubModules) }
    }

    private var sectionPicker: some View {
        Picker("Food section", selection: $section) {
            ForEach(visibleSections, id: \.self) { item in
                Text(sectionLabel(item)).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private func sectionLabel(_ section: FoodHubSection) -> String {
        switch section {
        case .week: "Weekly plan"
        case .snacks: "Snacks"
        case .recipes: "Recipes"
        }
    }

    private func normalizeSection() {
        if !section.isVisible(in: appState.hubModules) {
            section = .week
        }
    }

    private func applyPendingFoodSection() {
        guard let pending = appState.pendingFoodSection else { return }
        if pending.isVisible(in: appState.hubModules) {
            section = pending
        }
        appState.pendingFoodSection = nil
    }

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let success = viewModel.successMessage {
                Text(success).font(.footnote.weight(.semibold)).foregroundStyle(HubTheme.sage)
            }
            if viewModel.isLoading && viewModel.meals.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 320)
            } else {
                if horizontalSizeClass == .compact {
                    compactWeeklyGrid
                } else {
                    weeklyGrid
                }
                if viewModel.canManage {
                    Text("Pick a saved recipe or type a meal name. Put each item on its own line to add sides. Leave blank to clear that slot.")
                        .font(.footnote)
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(item: $viewModel.groceryPreview) { preview in
            MealGroceryPreviewSheet(preview: preview) { titles in
                await viewModel.addToGroceries(titles)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom) {
                mealHeaderTitle
                Spacer()
                mealActions
            }

            VStack(alignment: .leading, spacing: 10) {
                mealHeaderTitle
                mealActions
            }
        }
    }

    @ViewBuilder
    private var mealHeaderTitle: some View {
        if horizontalSizeClass != .compact {
            Text("Weekly meals")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var mealActions: some View {
        if viewModel.canManage {
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.saveMealPlan() }
                } label: {
                    Label("Save meal plan", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                .disabled(viewModel.isWorking || !viewModel.hasUnsavedChanges)

                Menu {
                    Button {
                        Task { await viewModel.prepareGroceryPreview() }
                    } label: {
                        Label("Add Week to Groceries", systemImage: "cart.badge.plus")
                    }

                    Button {
                        Task { await viewModel.copyPreviousWeek() }
                    } label: {
                        Label("Copy Last Week", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.clearWeek() }
                    } label: {
                        Label("Clear Week", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
                .disabled(viewModel.isWorking)
            }
        }
    }

    private var weeklyGrid: some View {
        HubCard {
            ScrollView {
                VStack(spacing: 0) {
                    mealHeaderRow

                    ForEach(Array(zip(viewModel.weekDates, viewModel.weekDateStrings)), id: \.1) { day, localDate in
                        HStack(alignment: .top, spacing: 0) {
                            dayHeader(day)

                            ForEach(mealSlots, id: \.self) { slot in
                                MealInputView(
                                    recipes: viewModel.recipes,
                                    readOnly: !viewModel.canManage,
                                    title: draftTitleBinding(localDate: localDate, slot: slot),
                                    recipeId: draftRecipeBinding(localDate: localDate, slot: slot),
                                    onTitleChanged: {
                                        viewModel.clearDraftRecipeIfTitleChanged(localDate: localDate, slot: slot)
                                    }
                                )
                                .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
                                .padding(8)
                                .overlay(alignment: .trailing) {
                                    Rectangle().fill(HubTheme.line).frame(width: 1)
                                }
                            }
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(HubTheme.line).frame(height: 1)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var compactWeeklyGrid: some View {
        VStack(spacing: 14) {
            ForEach(Array(zip(viewModel.weekDates, viewModel.weekDateStrings)), id: \.1) { day, localDate in
                HubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone).uppercased())
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                            Text(DateHelpers.dayNumber(day, timezone: viewModel.timezone))
                                .font(.title3.weight(.semibold))
                            Spacer()
                        }

                        ForEach(mealSlots, id: \.self) { slot in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(slot.label.uppercased())
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(HubTheme.muted)
                                MealInputView(
                                    recipes: viewModel.recipes,
                                    readOnly: !viewModel.canManage,
                                    title: draftTitleBinding(localDate: localDate, slot: slot),
                                    recipeId: draftRecipeBinding(localDate: localDate, slot: slot),
                                    onTitleChanged: {
                                        viewModel.clearDraftRecipeIfTitleChanged(localDate: localDate, slot: slot)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var mealHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 96, height: 1)

            ForEach(mealSlots, id: \.self) { slot in
                Text(slot.label.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(HubTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(HubTheme.line).frame(width: 1)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubTheme.line).frame(height: 1)
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone).uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
            Text(DateHelpers.dayNumber(day, timezone: viewModel.timezone))
                .font(.title2.weight(.semibold))
        }
        .frame(width: 96, alignment: .leading)
        .padding(.top, 16)
        .padding(.leading, 10)
    }

    private func draftTitleBinding(localDate: String, slot: MealSlot) -> Binding<String> {
        Binding(
            get: { viewModel.mealDraft(localDate: localDate, slot: slot).title },
            set: { viewModel.updateDraftTitle(localDate: localDate, slot: slot, title: $0) }
        )
    }

    private func draftRecipeBinding(localDate: String, slot: MealSlot) -> Binding<String?> {
        Binding(
            get: { viewModel.mealDraft(localDate: localDate, slot: slot).recipeId },
            set: { viewModel.updateDraftRecipe(localDate: localDate, slot: slot, recipeId: $0) }
        )
    }
}
