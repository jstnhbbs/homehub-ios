import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = MealsViewModel()
    @State private var section: FoodHubSection = .week
    @State private var pickerTarget: MealSlotRef?
    @State private var dropTarget: MealSlotRef?
    @State private var confirmClearWeek = false
    @State private var scrolledWeekOffset: Int?

    var body: some View {
        foodContent
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
        Picker("Food Section", selection: $section) {
            ForEach(visibleSections, id: \.self) { item in
                Text(sectionLabel(item)).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private func sectionLabel(_ section: FoodHubSection) -> String {
        switch section {
        case .week: "Weekly Plan"
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

    // MARK: - Week

    /// Wide enough for the week grid to keep room beside a sidebar.
    private static let sidebarWidth: CGFloat = 1000

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            weekNavigator
            messages
            if horizontalSizeClass == .compact {
                compactDayList
            } else {
                GeometryReader { proxy in
                    if proxy.size.width >= Self.sidebarWidth {
                        HStack(alignment: .top, spacing: 20) {
                            weeklyGrid
                            mealsSidebar
                                .frame(width: 340)
                        }
                    } else {
                        weeklyGrid
                    }
                }
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task {
            viewModel.bind(to: appState)
            await viewModel.load(refreshRecipes: true)
        }
        .sheet(item: $viewModel.groceryPreview) { preview in
            MealGroceryPreviewSheet(preview: preview) { titles in
                await viewModel.addToGroceries(titles)
            }
        }
        .sheet(item: $pickerTarget) { ref in
            MealPickerSheet(viewModel: viewModel, ref: ref)
        }
        .confirmationDialog("Clear every meal this week?", isPresented: $confirmClearWeek, titleVisibility: .visible) {
            Button("Clear Week", role: .destructive) {
                Task { await viewModel.clearWeek() }
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
            Text("Weekly Meals")
                .font(HubTheme.pageTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var mealActions: some View {
        if viewModel.canManage {
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
                    confirmClearWeek = true
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

    private var weekNavigator: some View {
        HStack(spacing: 10) {
            weekArrow("chevron.left", label: "Previous week") {
                await viewModel.changeWeek(by: -1)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.weekRangeLabel)
                    .font(.headline)
                if let subtitle = viewModel.weekSubtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
            .frame(minWidth: 110, alignment: .leading)

            weekArrow("chevron.right", label: "Next week") {
                await viewModel.changeWeek(by: 1)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
            }

            if !viewModel.isCurrentWeek {
                Button("Today") {
                    Task { await viewModel.goToThisWeek() }
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
            }
        }
    }

    private func weekArrow(_ systemImage: String, label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .background(HubTheme.tileQuiet)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var messages: some View {
        if let error = viewModel.errorMessage {
            Text(error).font(.footnote).foregroundStyle(.red)
        }
        if let success = viewModel.successMessage {
            Text(success)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HubTheme.accentText)
                .task(id: success) {
                    try? await Task.sleep(for: .seconds(3))
                    if viewModel.successMessage == success {
                        viewModel.successMessage = nil
                    }
                }
        }
    }

    // MARK: - iPhone: one section per day

    private var compactDayList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(zip(viewModel.weekDates, viewModel.weekDateStrings)), id: \.1) { day, localDate in
                    Section {
                        ForEach(MealSlot.planningSlots, id: \.self) { slot in
                            slotRow(localDate: localDate, slot: slot)
                                .id(slot == .breakfast ? "day-\(localDate)" : "\(localDate)-\(slot.rawValue)")
                        }
                    } header: {
                        dayHeaderRow(day, localDate: localDate)
                    }
                }

                if viewModel.canManage {
                    Text("Tap a meal to change it. Swipe to clear or copy to tomorrow, or press and hold to drag it to another slot.")
                        .font(.footnote)
                        .foregroundStyle(HubTheme.muted)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .hubPageBackground()
            .refreshable { await viewModel.load(refreshRecipes: true) }
            .onChange(of: viewModel.isLoading) { _, loading in
                // Jump to today (or the first day) when a week appears, not on every refresh.
                guard !loading, scrolledWeekOffset != viewModel.weekOffset else { return }
                scrolledWeekOffset = viewModel.weekOffset
                let target = viewModel.isCurrentWeek ? viewModel.todayString : viewModel.weekStart
                withAnimation { proxy.scrollTo("day-\(target)", anchor: .top) }
            }
        }
    }

    private func slotRow(localDate: String, slot: MealSlot) -> some View {
        let ref = MealSlotRef(localDate: localDate, slot: slot)
        let meal = viewModel.meal(ref)
        return HStack(alignment: .top, spacing: 12) {
            Text(slot.label.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
                .frame(width: 78, alignment: .leading)
                .padding(.top, 3)
            MealTitleLabel(meal: meal, canManage: viewModel.canManage)
            Spacer(minLength: 0)
            if meal?.recipeId != nil {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(HubTheme.accentText)
                    .padding(.top, 3)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 36)
        .listRowBackground(dropTarget == ref ? HubTheme.sage.opacity(0.18) : HubTheme.tile)
        .modifier(interactions(ref: ref, meal: meal))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if viewModel.canManage, meal != nil {
                Button(role: .destructive) {
                    Task { await viewModel.clearMeal(ref) }
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }
        }
        .swipeActions(edge: .leading) {
            if viewModel.canManage, meal != nil {
                Button {
                    Task { await viewModel.copyMeal(from: ref, daysAhead: 1) }
                } label: {
                    Label("Tomorrow", systemImage: "arrow.turn.down.right")
                }
                .tint(HubTheme.accentText)
            }
        }
    }

    private func dayHeaderRow(_ day: Date, localDate: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone).uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
            Text(DateHelpers.dayNumber(day, timezone: viewModel.timezone))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            if localDate == viewModel.todayString {
                todayBadge
            }
            Spacer()
        }
        .textCase(nil)
    }

    private var todayBadge: some View {
        Text("Today")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(HubTheme.onAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(HubTheme.sage)
            .clipShape(Capsule())
    }

    // MARK: - iPad: sidebar

    private var slotRefs: [MealSlotRef] {
        viewModel.weekDateStrings.flatMap { date in
            MealSlot.planningSlots.map { MealSlotRef(localDate: date, slot: $0) }
        }
    }

    private var plannedCount: Int {
        slotRefs.filter { viewModel.meal($0) != nil }.count
    }

    private var mealsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isCurrentWeek {
                    todayCard
                }
                if viewModel.canManage {
                    stillToPlanCard
                    weekActionsCard
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Today's three meals at a glance, in larger type than the grid; tap one to change it.
    private var todayCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Today", systemImage: "fork.knife")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
                ForEach(MealSlot.planningSlots, id: \.self) { slot in
                    let ref = MealSlotRef(localDate: viewModel.todayString, slot: slot)
                    let meal = viewModel.meal(ref)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.label.uppercased())
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        if let meal {
                            Text(meal.title)
                                .font(.headline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                        } else {
                            Text(viewModel.canManage ? "Nothing planned. Tap to add." : "Not planned")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(HubTheme.muted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HubTheme.tileQuiet)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.canManage { pickerTarget = ref }
                    }
                }
            }
        }
    }

    /// For each meal of the day, the days still empty this week. Tapping a day opens the picker for it.
    private var stillToPlanCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Still to Plan", systemImage: "calendar.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
                Text("\(plannedCount) of \(slotRefs.count) meals planned")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.muted)

                ForEach(MealSlot.planningSlots, id: \.self) { slot in
                    let open = zip(viewModel.weekDates, viewModel.weekDateStrings).filter { _, date in
                        viewModel.meal(MealSlotRef(localDate: date, slot: slot)) == nil
                            && (!viewModel.isCurrentWeek || date >= viewModel.todayString)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(slot.label.uppercased())
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(HubTheme.muted)
                        if open.isEmpty {
                            Label("All set", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(HubTheme.accentText)
                        } else {
                            TagFlowLayout(spacing: 6) {
                                ForEach(open, id: \.1) { day, date in
                                    Button {
                                        pickerTarget = MealSlotRef(localDate: date, slot: slot)
                                    } label: {
                                        Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone))
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(HubTheme.tileQuiet)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// The week-level actions that otherwise sit in the More menu.
    private var weekActionsCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("This Week", systemImage: "cart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
                Button {
                    Task { await viewModel.prepareGroceryPreview() }
                } label: {
                    Label("Add Week to Groceries", systemImage: "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                Button {
                    Task { await viewModel.copyPreviousWeek() }
                } label: {
                    Label("Copy Last Week", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
            }
            .disabled(viewModel.isWorking)
        }
    }

    // MARK: - iPad: week grid

    private var weeklyGrid: some View {
        HubCard {
            ScrollView {
                VStack(spacing: 0) {
                    mealHeaderRow

                    ForEach(Array(zip(viewModel.weekDates, viewModel.weekDateStrings)), id: \.1) { day, localDate in
                        HStack(alignment: .top, spacing: 0) {
                            gridDayHeader(day, localDate: localDate)

                            ForEach(MealSlot.planningSlots, id: \.self) { slot in
                                gridCell(localDate: localDate, slot: slot)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(HubTheme.line).frame(height: 1)
                        }
                    }

                    if viewModel.canManage {
                        Text("Tap a meal to change it, press and hold to drag it to another slot, or use the context menu to copy it.")
                            .font(.footnote)
                            .foregroundStyle(HubTheme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await viewModel.load(refreshRecipes: true) }
        }
    }

    private func gridCell(localDate: String, slot: MealSlot) -> some View {
        let ref = MealSlotRef(localDate: localDate, slot: slot)
        let meal = viewModel.meal(ref)
        return HStack(alignment: .top, spacing: 6) {
            MealTitleLabel(meal: meal, canManage: viewModel.canManage)
            Spacer(minLength: 0)
            if meal?.recipeId != nil {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(HubTheme.accentText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(dropTarget == ref ? HubTheme.sage.opacity(0.2) : HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .modifier(interactions(ref: ref, meal: meal))
        .padding(8)
        .overlay(alignment: .trailing) {
            Rectangle().fill(HubTheme.line).frame(width: 1)
        }
    }

    private var mealHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 96, height: 1)

            ForEach(MealSlot.planningSlots, id: \.self) { slot in
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

    private func gridDayHeader(_ day: Date, localDate: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateHelpers.weekdayShort(day, timezone: viewModel.timezone).uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(HubTheme.muted)
            Text(DateHelpers.dayNumber(day, timezone: viewModel.timezone))
                .font(.title2.weight(.semibold))
            if localDate == viewModel.todayString {
                todayBadge
            }
        }
        .frame(width: 96, alignment: .leading)
        .padding(.top, 16)
        .padding(.leading, 10)
    }

    // MARK: - Shared slot behavior

    private func interactions(ref: MealSlotRef, meal: Meal?) -> MealSlotInteractions {
        MealSlotInteractions(
            ref: ref,
            meal: meal,
            canManage: viewModel.canManage,
            dropTarget: $dropTarget,
            onEdit: { pickerTarget = ref },
            onDrop: { token in
                Task { await viewModel.moveMeal(fromToken: token, to: ref) }
            },
            onClear: {
                Task { await viewModel.clearMeal(ref) }
            },
            onCopy: { days in
                Task { await viewModel.copyMeal(from: ref, daysAhead: days) }
            }
        )
    }
}

/// What a planned (or empty) slot shows.
private struct MealTitleLabel: View {
    let meal: Meal?
    let canManage: Bool

    var body: some View {
        if let meal {
            Text(meal.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        } else if canManage {
            Label("Add Meal", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HubTheme.muted.opacity(0.8))
        } else {
            Text("Not planned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
        }
    }
}

/// Tap to edit, a context menu, and drag and drop. Read-only viewers get none of it.
private struct MealSlotInteractions: ViewModifier {
    let ref: MealSlotRef
    let meal: Meal?
    let canManage: Bool
    @Binding var dropTarget: MealSlotRef?
    let onEdit: () -> Void
    let onDrop: (String) -> Void
    let onClear: () -> Void
    let onCopy: (Int) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if canManage {
            let interactive = content
                .contentShape(Rectangle())
                .onTapGesture(perform: onEdit)
                .accessibilityAddTraits(.isButton)
                .contextMenu {
                    Button(action: onEdit) {
                        Label(meal == nil ? "Add Meal" : "Change Meal", systemImage: "pencil")
                    }
                    if meal != nil {
                        Button {
                            onCopy(1)
                        } label: {
                            Label("Copy to Tomorrow", systemImage: "arrow.turn.down.right")
                        }
                        Button {
                            onCopy(7)
                        } label: {
                            Label("Repeat Next Week", systemImage: "repeat")
                        }
                        Divider()
                        Button(role: .destructive, action: onClear) {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                    }
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let token = items.first(where: { $0.hasPrefix(MealSlotRef.tokenPrefix) }) else {
                        return false
                    }
                    onDrop(token)
                    return true
                } isTargeted: { targeted in
                    if targeted {
                        dropTarget = ref
                    } else if dropTarget == ref {
                        dropTarget = nil
                    }
                }

            if meal != nil {
                interactive.draggable(ref.token)
            } else {
                interactive
            }
        } else {
            content
        }
    }
}
