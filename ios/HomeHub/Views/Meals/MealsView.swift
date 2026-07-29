import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MealsViewModel()
    @State private var section: FoodHubSection = .week

    private let mealSlots: [MealSlot] = [.breakfast, .lunch, .dinner]

    var body: some View {
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
            if viewModel.isLoading && viewModel.meals.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 320)
            } else {
                weeklyGrid
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
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's cooking?")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(HubTheme.sage)
                Text("Weekly meals")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            Spacer()
            if viewModel.canManage {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.copyPreviousWeek() }
                    } label: {
                        Label("Copy last week", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondary))
                    .disabled(viewModel.isWorking)

                    Button {
                        Task { await viewModel.clearWeek() }
                    } label: {
                        Label("Clear week", systemImage: "trash")
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .secondaryDestructive))
                    .disabled(viewModel.isWorking)
                }
            }
        }
    }

    private var weeklyGrid: some View {
        HubCard {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 100, height: 1)
                        ForEach(Array(viewModel.weekDates.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 2) {
                                Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone).uppercased())
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(HubTheme.muted)
                                Text(DateHelpers.dayNumber(day, timezone: viewModel.timezone))
                                    .font(.title2.weight(.semibold))
                            }
                            .frame(width: 140)
                            .padding(.vertical, 12)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(HubTheme.line).frame(width: 1)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(HubTheme.line).frame(height: 1)
                    }

                    ForEach(mealSlots, id: \.self) { slot in
                        HStack(alignment: .top, spacing: 0) {
                            Text(slot.label.uppercased())
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                                .frame(width: 100, alignment: .leading)
                                .padding(.top, 16)
                                .padding(.leading, 8)

                            ForEach(Array(viewModel.weekDateStrings.enumerated()), id: \.offset) { _, localDate in
                                MealInputView(
                                    localDate: localDate,
                                    slot: slot,
                                    meal: viewModel.meal(localDate: localDate, slot: slot),
                                    recipes: viewModel.recipes,
                                    readOnly: !viewModel.canManage
                                ) { title, recipeId in
                                    await viewModel.saveMeal(
                                        localDate: localDate,
                                        slot: slot,
                                        title: title,
                                        recipeId: recipeId
                                    )
                                }
                                .frame(width: 140, alignment: .top)
                                .frame(minHeight: 120, alignment: .top)
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
        }
    }
}
