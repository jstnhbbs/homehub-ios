import SwiftUI

struct SnacksView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = SnacksViewModel()
    @FocusState private var focusedField: SnackFocusField?

    private enum SnackFocusField: Hashable {
        case add
        case edit
    }

    /// Wide enough for the checklist to sit beside a panel with the date, progress and settings.
    private static let sidePanelWidth: CGFloat = 820

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= Self.sidePanelWidth, horizontalSizeClass != .compact {
                HStack(alignment: .top, spacing: 20) {
                    List {
                        messagesSection
                        snackChecklistSection
                    }
                    .listStyle(.insetGrouped)
                    sidePanel
                        .frame(width: 340)
                }
            } else {
                List {
                    headerSection
                    messagesSection
                    snackChecklistSection
                    perChildSection
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onChange(of: viewModel.editingSnack) { _, snack in
            focusedField = snack == nil ? nil : .edit
        }
    }

    /// The date, progress, reset and the per-child setting, as cards beside the checklist.
    private var sidePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HubCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's snacks")
                            .font(HubTheme.sectionTitle)
                        if !viewModel.dateLabel.isEmpty {
                            Text(viewModel.dateLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }
                        if !viewModel.snackOptions.isEmpty {
                            Text("\(viewModel.eaten.count) of \(viewModel.snackOptions.count)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(viewModel.usesPerChild ? "snacks eaten by everyone" : "snacks eaten")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                            ProgressView(
                                value: Double(viewModel.eaten.count),
                                total: Double(max(viewModel.snackOptions.count, 1))
                            )
                            .tint(HubTheme.sage)
                            Button {
                                Task { await viewModel.resetChecklist() }
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(HubButtonStyle(emphasis: .secondary))
                            .disabled(viewModel.isWorking)
                        }
                    }
                }

                if viewModel.canManage && (viewModel.canChoosePerChild || viewModel.tracksPerChild) {
                    HubCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(
                                "Track snacks for each child",
                                isOn: Binding(
                                    get: { viewModel.tracksPerChild },
                                    set: { enabled in Task { await viewModel.setPerChild(enabled) } }
                                )
                            )
                            .font(.subheadline.weight(.semibold))
                            .disabled(viewModel.isWorking)
                            Text("Off, one tap marks a snack eaten for everyone. On, each child has their own circle, which suits kids who eat different things.")
                                .font(.footnote)
                                .foregroundStyle(HubTheme.muted)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if horizontalSizeClass != .compact {
                        Text("Today's snacks")
                            .font(HubTheme.sectionTitle)
                    }
                    if !viewModel.dateLabel.isEmpty {
                        Text(viewModel.dateLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                }
                Spacer()
                if !viewModel.snackOptions.isEmpty {
                    Button {
                        Task { await viewModel.resetChecklist() }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.isWorking)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } else if let success = viewModel.successMessage {
            Section {
                Text(success)
                    .font(.footnote)
                    .foregroundStyle(HubTheme.sage)
            }
        }
    }

    /// Parents choose whether a snack is checked off once for the household or by each child.
    @ViewBuilder
    private var perChildSection: some View {
        if viewModel.canManage && (viewModel.canChoosePerChild || viewModel.tracksPerChild) {
            Section {
                Toggle(
                    "Track snacks for each child",
                    isOn: Binding(
                        get: { viewModel.tracksPerChild },
                        set: { enabled in Task { await viewModel.setPerChild(enabled) } }
                    )
                )
                .disabled(viewModel.isWorking)
            } footer: {
                Text("Off, one tap marks a snack eaten for everyone. On, each child has their own circle, which suits kids who eat different things.")
            }
        }
    }

    @ViewBuilder
    private var snackChecklistSection: some View {
        Section {
            if viewModel.isLoading && viewModel.snackOptions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if viewModel.snackOptions.isEmpty && !viewModel.canManage {
                Text("No snacks listed yet.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
            } else {
                ForEach(viewModel.displayedSnacks, id: \.self) { snack in
                    snackRow(snack)
                }
            }

            if viewModel.canManage {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HubTheme.sage)
                    TextField("New snack", text: $viewModel.newSnackText)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .add)
                        .onSubmit {
                            Task {
                                if await viewModel.addSnack() {
                                    focusedField = .add
                                }
                            }
                        }
                }
                .disabled(viewModel.isWorking)
            }
        } header: {
            Label("Snacks", systemImage: "carrot.fill")
        } footer: {
            if !viewModel.snackOptions.isEmpty {
                Text(viewModel.usesPerChild
                    ? "\(viewModel.eaten.count) of \(viewModel.snackOptions.count) snacks eaten by everyone today"
                    : "\(viewModel.eaten.count) of \(viewModel.snackOptions.count) eaten today")
            } else if viewModel.canManage {
                Text("Add a snack below to start today's checklist.")
            }
        }
    }

    /// The snack's name with a circle for each child to tick off once they have had it.
    private func perChildRow(_ snack: String) -> some View {
        let done = viewModel.eaten.contains(snack)
        return VStack(alignment: .leading, spacing: 8) {
            Text(snack)
                .font(.body.weight(.semibold))
                .foregroundStyle(done ? HubTheme.muted : .primary)
                .strikethrough(done, color: HubTheme.muted)
            SnackChildChips(
                snack: snack,
                children: viewModel.children,
                records: viewModel.records
            ) { child, eaten in
                await viewModel.toggleSnack(snack, profileId: child.id, completed: eaten)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func snackRow(_ snack: String) -> some View {
        Group {
            if viewModel.editingSnack == snack {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HubTheme.sage)
                    TextField("Snack name", text: $viewModel.editDraft)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .edit)
                        .onSubmit {
                            Task { _ = await viewModel.commitEditing() }
                        }
                    Button("Cancel") {
                        viewModel.cancelEditing()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
                }
            } else {
                if viewModel.usesPerChild {
                    perChildRow(snack)
                } else {
                    SnackCheckRow(
                        label: snack,
                        isEaten: viewModel.eaten.contains(snack)
                    ) {
                        await viewModel.toggleSnack(snack, completed: !viewModel.eaten.contains(snack))
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if viewModel.canManage {
                Button(role: .destructive) {
                    Task { await viewModel.deleteSnack(snack) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    viewModel.beginEditing(snack)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.indigo)
            }
        }
    }
}

private struct SnackCheckRow: View {
    let label: String
    let isEaten: Bool
    var onToggle: () async -> Void

    @State private var isChecked: Bool

    init(label: String, isEaten: Bool, onToggle: @escaping () async -> Void) {
        self.label = label
        self.isEaten = isEaten
        self.onToggle = onToggle
        _isChecked = State(initialValue: isEaten)
    }

    var body: some View {
        Button {
            Task {
                isChecked.toggle()
                await onToggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? HubTheme.sage : HubTheme.muted)
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isChecked ? HubTheme.muted : .primary)
                    .strikethrough(isChecked, color: HubTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: isEaten) { _, eaten in
            isChecked = eaten
        }
    }
}
