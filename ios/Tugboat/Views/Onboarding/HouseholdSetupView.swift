import SwiftUI

/// Everything the guided setup's steps share: the household's people, and what has been added in this sitting
/// (so a starter shows "Added" instead of being added twice).
@MainActor
final class HouseholdSetupModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var added: Set<String> = []
    @Published var errorMessage: String?
    @Published var isWorking = false

    func load(_ appState: AppState) async {
        if let loaded = try? await appState.api.fetchProfiles() { profiles = loaded }
    }

    var children: [Profile] { profiles.filter { $0.profileType == .child } }
    var choreAssignees: [Profile] { profiles.filter(\.canBeAssignedChores) }
}

/// The guided setup: a checklist of four steps, each skippable, and a last page about the rest of the app. Shown
/// once after a household is created, then from Today's "Finish Setting Up" card or Settings.
struct HouseholdSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = HouseholdSetupModel()

    private var state: HouseholdSetupState { appState.setupState ?? HouseholdSetupState() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Up Your Household")
                            .font(HubTheme.pageTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("Tugboat can do a lot. Start with a few things and it will feel like yours. Do them in any order, and skip what you like.")
                            .font(.body)
                            .foregroundStyle(HubTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(state.doneCount), total: Double(state.totalCount))
                            .tint(HubTheme.accent)
                        Text(state.progressText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 0) {
                        ForEach(Array(HouseholdSetupStep.allCases.enumerated()), id: \.element) { index, step in
                            if index > 0 { Divider().overlay(HubTheme.line) }
                            NavigationLink(value: step) { stepRow(step) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .hubGlass(cornerRadius: 22)

                    NavigationLink(value: ExploreDestination()) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(HubTheme.accentText)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Everything Else")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Calendar, Sleep, Snacks and more. Hide the pages you won't use.")
                                    .font(.subheadline)
                                    .foregroundStyle(HubTheme.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(HubTheme.muted)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .hubGlass(cornerRadius: 22)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(HubTheme.canvas)
            .navigationDestination(for: HouseholdSetupStep.self) { step in
                switch step {
                case .family: SetupFamilyStep(model: model)
                case .routines: SetupRoutinesStep(model: model)
                case .chores: SetupChoresStep(model: model)
                case .food: SetupFoodStep(model: model)
                }
            }
            .navigationDestination(for: ExploreDestination.self) { _ in SetupExploreStep() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(state.isFinished ? "Done" : "Finish Later") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !state.isFinished {
                    Button("Don't Show This Again") {
                        appState.dismissSetupCard()
                        dismiss()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
                    .background(HubTheme.canvas)
                }
            }
        }
        .task { await model.load(appState) }
    }

    private struct ExploreDestination: Hashable {}

    private func stepRow(_ step: HouseholdSetupStep) -> some View {
        let done = state.isDone(step)
        return HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : step.systemImage)
                .font(.title3)
                .foregroundStyle(done ? HubTheme.accentText : HubTheme.muted)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(HubTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HubTheme.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not done")
        .accessibilityHint("Opens this step")
    }
}

// MARK: - Shared pieces

/// A page for one step: a title, a sentence, then the step's content in cards.
private struct SetupStepPage<Content: View>: View {
    let title: String
    let intro: String
    let model: HouseholdSetupModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(intro)
                    .font(.body)
                    .foregroundStyle(HubTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                content()
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(HubTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.errorMessage = nil }
    }
}

/// A row for one thing to add: a title, a line under it and an Add button that turns into "Added".
private struct SetupAddRow: View {
    let title: String
    let subtitle: String?
    let isAdded: Bool
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(HubTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if isAdded {
                Label("Added", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HubTheme.accentText)
            } else {
                Button(action: action) { SetupPill(text: "Add") }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// The small filled button the setup steps use to add something.
private struct SetupPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(HubTheme.onAccent)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(HubTheme.accent, in: Capsule())
    }
}

private struct SetupCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hubGlass(cornerRadius: 22)
    }
}

/// A line to type something and add it, for a step's own entry as well as its suggestions.
private struct SetupAddField: View {
    let placeholder: String
    let buttonLabel: String
    @Binding var text: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(HubFieldStyle())
                .submitLabel(.done)
                .onSubmit(action)
            Button(action: action) { SetupPill(text: buttonLabel) }
                .buttonStyle(.plain)
                .disabled(isWorking || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Family

private struct SetupFamilyStep: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: HouseholdSetupModel
    @State private var showingAdd = false

    private var timezone: TimeZone {
        appState.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var body: some View {
        SetupStepPage(
            title: HouseholdSetupStep.family.title,
            intro: "Everyone in the house gets a profile and a color, so chores, routines and naps can belong to someone. Children don't need their own account.",
            model: model
        ) {
            SetupCard {
                ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { Divider().overlay(HubTheme.line) }
                    HStack(spacing: 12) {
                        ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color, size: 36)
                        Text(profile.name).font(.headline)
                        Spacer()
                        Text(profile.profileType == .child ? "Child" : "Adult")
                            .font(.subheadline)
                            .foregroundStyle(HubTheme.muted)
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
                if model.profiles.isEmpty {
                    Text("No one yet.")
                        .foregroundStyle(HubTheme.muted)
                        .padding(.vertical, 12)
                }
            }

            Button {
                showingAdd = true
            } label: {
                Label("Add Family Member", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                ScrollView {
                    ProfileFormView(
                        mode: .manage,
                        timezone: timezone,
                        submitLabel: "Add Member",
                        otherProfiles: model.profiles
                    ) { input in
                        do {
                            _ = try await appState.api.addProfile(input)
                            await model.load(appState)
                            await appState.refreshDashboard()
                            appState.completeSetupStep(.family)
                            showingAdd = false
                            return true
                        } catch {
                            model.errorMessage = error.localizedDescription
                            return false
                        }
                    }
                    .padding()
                    if let message = model.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.red).padding(.horizontal)
                    }
                }
                .background(HubTheme.canvas)
                .navigationTitle("Add Family Member")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAdd = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}

// MARK: - Routines

private struct SetupRoutinesStep: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: HouseholdSetupModel
    @State private var profileId: String?
    @State private var started = false

    private var people: [Profile] { model.children.isEmpty ? model.profiles : model.children }

    var body: some View {
        SetupStepPage(
            title: HouseholdSetupStep.routines.title,
            intro: "A routine is a list of steps to tick off at a time of day. Add a starter, and change its steps later on the Routines page.",
            model: model
        ) {
            if people.count > 1 {
                SetupCard {
                    HStack {
                        Text("For").font(.headline)
                        Spacer()
                        ProfilePickerField(profiles: people, profileId: $profileId)
                    }
                    .frame(minHeight: 44)
                }
            }

            SetupCard {
                ForEach(Array(HouseholdSetupStarters.routines.enumerated()), id: \.element.id) { index, starter in
                    if index > 0 { Divider().overlay(HubTheme.line) }
                    SetupAddRow(
                        title: starter.name,
                        subtitle: starter.steps.joined(separator: ", "),
                        isAdded: model.added.contains(key(starter)),
                        isWorking: model.isWorking
                    ) { Task { await add(starter) } }
                }
            }
        }
        .onChange(of: people.map(\.id)) { _, _ in chooseDefault() }
        .onAppear { chooseDefault() }
    }

    private func chooseDefault() {
        guard !started || (profileId != nil && !people.contains { $0.id == profileId }) else { return }
        started = true
        profileId = people.first?.id
    }

    private func key(_ starter: RoutineStarter) -> String { "routine|\(profileId ?? "")|\(starter.name)" }

    private func add(_ starter: RoutineStarter) async {
        model.isWorking = true
        model.errorMessage = nil
        defer { model.isWorking = false }
        do {
            _ = try await appState.api.addRoutine(RoutineInput(
                name: starter.name,
                period: RoutinePeriod(rawValue: starter.period) ?? .morning,
                profileId: profileId,
                days: RoutineDays.storage(RoutineDays.everyDay),
                steps: starter.steps
            ))
            model.added.insert(key(starter))
            appState.completeSetupStep(.routines)
            await appState.refreshDashboard()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Chores

private struct SetupChoresStep: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: HouseholdSetupModel
    @State private var profileId: String?
    @State private var custom = ""

    var body: some View {
        SetupStepPage(
            title: HouseholdSetupStep.chores.title,
            intro: "Chores repeat on their own and can be given to someone, or to everyone. Change a chore's repeat, time or person later on the Chores page.",
            model: model
        ) {
            if model.choreAssignees.count > 1 {
                SetupCard {
                    HStack {
                        Text("Give to").font(.headline)
                        Spacer()
                        ProfilePickerField(profiles: model.choreAssignees, profileId: $profileId)
                    }
                    .frame(minHeight: 44)
                }
            }

            SetupCard {
                ForEach(Array(HouseholdSetupStarters.chores.enumerated()), id: \.element.id) { index, starter in
                    if index > 0 { Divider().overlay(HubTheme.line) }
                    SetupAddRow(
                        title: starter.title,
                        subtitle: starter.repeatText,
                        isAdded: model.added.contains(key(starter.title)),
                        isWorking: model.isWorking
                    ) { Task { await add(title: starter.title, daily: starter.daily, weekday: starter.weekday) } }
                }
            }

            SetupAddField(placeholder: "Add your own chore", buttonLabel: "Add", text: $custom, isWorking: model.isWorking) {
                let title = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                Task {
                    if await add(title: title, daily: true, weekday: 0) { custom = "" }
                }
            }
        }
    }

    private func key(_ title: String) -> String { "chore|\(profileId ?? "")|\(title)" }

    @discardableResult
    private func add(title: String, daily: Bool, weekday: Int) async -> Bool {
        model.isWorking = true
        model.errorMessage = nil
        defer { model.isWorking = false }
        do {
            let rule = daily ? ChoreRepeatRule.daily : ChoreRepeatRule(unit: .week)
            _ = try await appState.api.addChore(ChoreHelpers.input(
                title: title,
                profileId: profileId,
                rule: rule,
                dueDate: nil,
                dueTime: nil,
                weekDay: String(weekday)
            ))
            model.added.insert(key(title))
            appState.completeSetupStep(.chores)
            await appState.refreshDashboard()
            return true
        } catch {
            model.errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - Food

private struct SetupFoodStep: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: HouseholdSetupModel
    @State private var dinner = ""
    @State private var grocery = ""

    private var timezone: TimeZone {
        appState.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var body: some View {
        SetupStepPage(
            title: HouseholdSetupStep.food.title,
            intro: "Put tonight's dinner on the plan and a few things on the grocery list. Recipes, the rest of the week and aisles come later.",
            model: model
        ) {
            sectionTitle("Tonight's Dinner")
            SetupAddField(placeholder: "What's for dinner?", buttonLabel: "Add", text: $dinner, isWorking: model.isWorking) {
                Task { await addDinner(dinner) }
            }
            suggestions(HouseholdSetupStarters.dinners, prefix: "dinner") { name in
                Task { await addDinner(name) }
            }

            sectionTitle("Grocery List")
            SetupAddField(placeholder: "Add an item", buttonLabel: "Add", text: $grocery, isWorking: model.isWorking) {
                Task { await addGrocery(grocery) }
            }
            suggestions(HouseholdSetupStarters.groceries, prefix: "grocery") { name in
                Task { await addGrocery(name) }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func suggestions(_ names: [String], prefix: String, action: @escaping (String) -> Void) -> some View {
        FlowChips(names: names, isAdded: { model.added.contains("\(prefix)|\($0)") }, action: action)
    }

    private func addDinner(_ text: String) async {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        model.isWorking = true
        model.errorMessage = nil
        defer { model.isWorking = false }
        do {
            try await appState.api.saveMeal(SaveMealRequest(
                localDate: DateHelpers.localDateIn(timezone: timezone),
                slot: .dinner,
                title: title,
                recipeId: nil,
                notes: nil
            ))
            model.added.insert("dinner|\(title)")
            dinner = ""
            appState.completeSetupStep(.food)
            await appState.refreshDashboard()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func addGrocery(_ text: String) async {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        model.isWorking = true
        model.errorMessage = nil
        defer { model.isWorking = false }
        do {
            // The same choice the Groceries page makes: the device's Reminders list when it can be used.
            appState.nativeReminders.refreshAccessStatus()
            if appState.nativeReminders.accessStatus == .authorized {
                _ = try appState.nativeReminders.addItem(title: title)
                appState.nativeGroceryItems = try await appState.nativeReminders.loadItems()
            } else {
                _ = try await appState.api.addGroceryItem(GroceryItemInput(title: title, category: nil))
            }
            model.added.insert("grocery|\(title)")
            grocery = ""
            appState.completeSetupStep(.food)
            await appState.refreshDashboard()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

/// Suggestions as tappable chips that wrap onto more lines.
private struct FlowChips: View {
    let names: [String]
    let isAdded: (String) -> Bool
    let action: (String) -> Void

    var body: some View {
        WrappingHStack(spacing: 8) {
            ForEach(names, id: \.self) { name in
                let added = isAdded(name)
                Button {
                    action(name)
                } label: {
                    Label(name, systemImage: added ? "checkmark" : "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(added ? HubTheme.muted : HubTheme.accentText)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(HubTheme.tile, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(added)
                .accessibilityLabel(added ? "\(name), added" : "Add \(name)")
            }
        }
    }
}

/// A left-to-right layout that wraps to a new line when a row is full.
private struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

// MARK: - Everything else

private struct SetupExploreStep: View {
    @EnvironmentObject private var appState: AppState

    private let modules: [HubModuleId] = [.calendar, .sleep, .snacks, .notes, .birthdays, .recipes]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The rest of Tugboat is here when you need it. Turn off a page you won't use and it leaves the tab bar. You can bring it back in Settings → Layout.")
                    .font(.body)
                    .foregroundStyle(HubTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                SetupCard {
                    ForEach(Array(modules.enumerated()), id: \.element) { index, module in
                        if index > 0 { Divider().overlay(HubTheme.line) }
                        Toggle(isOn: binding(for: module)) {
                            HStack(spacing: 12) {
                                Image(systemName: module.systemImage)
                                    .foregroundStyle(HubTheme.accentText)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.label).font(.headline)
                                    if let blurb = HouseholdSetupTour.blurb(forModule: module.rawValue) {
                                        Text(blurb)
                                            .font(.subheadline)
                                            .foregroundStyle(HubTheme.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(HubTheme.canvas)
        .navigationTitle("Everything Else")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for module: HubModuleId) -> Binding<Bool> {
        Binding(
            get: { appState.hubModules.isEnabled(module) },
            set: { appState.saveHubModules(appState.hubModules.updating(module, enabled: $0)) }
        )
    }
}

// MARK: - Today's card

/// "Finish Setting Up", at the top of Today until the steps are done or it is closed.
struct SetupProgressCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let state = appState.setupState, state.showsCard, appState.canManageHousehold {
            HStack(spacing: 12) {
                Button {
                    appState.openSetup()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(HubTheme.accentText)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finish Setting Up")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(state.nextStep.map { "\(state.progressText) · Next: \($0.title)" } ?? state.progressText)
                                .font(.subheadline)
                                .foregroundStyle(HubTheme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { appState.dismissSetupCard() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss Setup")
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .hubGlass(cornerRadius: 22)
        }
    }
}
