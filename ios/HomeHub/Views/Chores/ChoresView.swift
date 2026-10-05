import SwiftUI

struct ChoresView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = ChoresViewModel()
    @State private var activeChoreEditor: ChoreEditorPresentation?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if let error = viewModel.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        choresContent(columns: [GridItem(.flexible())])
                    }
                }
            } else {
                wideContent
            }
        }
        .sheet(item: $activeChoreEditor) { editor in
            ChoreEditorSheet(
                editor: editor,
                chores: viewModel.chores,
                profiles: viewModel.profiles,
                viewModel: viewModel
            )
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    choresContent(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)])
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func choresContent(columns: [GridItem]) -> some View {
        if viewModel.isLoading && viewModel.chores.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.groups) { group in
                    ChoreGroupCard(group: group, viewModel: viewModel) { chore in
                        activeChoreEditor = .edit(chore.id)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            if horizontalSizeClass != .compact {
                Text("Chore chart")
                    .font(HubTheme.pageTitle)
            }
            Spacer()
            if viewModel.canManage {
                Button {
                    activeChoreEditor = .add(UUID())
                } label: {
                    Label("Add Chore", systemImage: "plus")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
            }
        }
    }
}

private struct ChoreGroupCard: View {
    let group: ChoreGroup
    @ObservedObject var viewModel: ChoresViewModel
    let onEdit: (ChoreRow) -> Void

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProfileAvatarView(name: group.name, color: group.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.title2.weight(.semibold))
                        Text("\(group.chores.count) \(group.chores.count == 1 ? "chore" : "chores")")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                }

                if group.chores.isEmpty {
                    Text("Assign shared chores here.")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(HubTheme.line)
                        )
                } else {
                    ForEach(group.chores) { chore in
                        ChoreItemRow(chore: chore, groupColor: group.color, viewModel: viewModel) {
                            onEdit(chore)
                        }
                    }
                }
            }
        }
    }
}

private struct ChoreItemRow: View {
    let chore: ChoreRow
    let groupColor: String
    @ObservedObject var viewModel: ChoresViewModel
    let onEdit: () -> Void

    @State private var isChecked: Bool

    init(chore: ChoreRow, groupColor: String, viewModel: ChoresViewModel, onEdit: @escaping () -> Void) {
        self.chore = chore
        self.groupColor = groupColor
        self.viewModel = viewModel
        self.onEdit = onEdit
        _isChecked = State(initialValue: chore.completed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CheckItemView(
                label: chore.title,
                detail: ChoreHelpers.choreCadenceDetail(cadence: chore.cadence, days: chore.days),
                color: groupColor,
                isChecked: $isChecked
            ) {
                // The row flips `isChecked` after this returns, so the state wanted is the opposite.
                await viewModel.toggleChore(chore, completed: !isChecked)
                await viewModel.load()
            }
            .disabled(chore.dueToday == false)
            .opacity(chore.dueToday == false ? 0.55 : 1)

            if chore.dueToday == false {
                Text("Not due today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .padding(.leading, 8)
            }

            if let dueDate = chore.dueDate {
                let label = DateHelpers.formatLocalDate(dueDate, timezone: viewModel.timezone, pattern: "EEE, MMM d")
                Text(chore.overdue == true ? "Overdue · \(label)" : "Due \(label)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(chore.overdue == true ? .red : HubTheme.muted)
                    .padding(.leading, 8)
            }

            if isChecked,
               let caption = CompletionHelpers.caption(
                   name: chore.completedByName,
                   completedAt: chore.completedAt,
                   timezone: viewModel.timezone
               ) {
                Label("Done by \(caption)", systemImage: "checkmark.circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                    .padding(.leading, 8)
            }

            if viewModel.canManage {
                Button(action: onEdit) {
                    Label("Edit Chore", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
            }
        }
        .contextMenu {
            if viewModel.canManage {
                Button(action: onEdit) {
                    Label("Edit Chore", systemImage: "pencil")
                }
            }
        }
    }
}

private enum ChoreEditorPresentation: Identifiable {
    case add(UUID)
    case edit(String)

    var id: String {
        switch self {
        case .add(let id):
            "add-\(id.uuidString)"
        case .edit(let choreId):
            "edit-\(choreId)"
        }
    }
}

private struct ChoreEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: ChoreEditorPresentation
    let chores: [ChoreRow]
    let profiles: [Profile]
    @ObservedObject var viewModel: ChoresViewModel

    private var chore: ChoreRow? {
        guard case .edit(let choreId) = editor else { return nil }
        return chores.first { $0.id == choreId }
    }

    private var title: String {
        switch editor {
        case .add:
            "Add Chore"
        case .edit:
            "Edit Chore"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch editor {
                    case .add:
                        ChoreFormView(
                            profiles: profiles,
                            timezone: viewModel.timezone,
                            submitLabel: "Add Chore"
                        ) { input in
                            let saved = await viewModel.createChore(input)
                            if saved {
                                dismiss()
                            }
                            return saved
                        }
                    case .edit:
                        if let chore {
                            ChoreFormView(
                                profiles: profiles,
                                chore: chore,
                                timezone: viewModel.timezone,
                                submitLabel: "Save Chore",
                                onSubmit: { input in
                                    let saved = await viewModel.updateChore(id: chore.id, input: input)
                                    if saved {
                                        dismiss()
                                    }
                                    return saved
                                },
                                onDelete: {
                                    let deleted = await viewModel.deleteChore(id: chore.id)
                                    if deleted {
                                        dismiss()
                                    }
                                    return deleted
                                }
                            )
                        } else {
                            ContentUnavailableView(
                                "Chore Missing",
                                systemImage: "checklist",
                                description: Text("This chore could not be found.")
                            )
                        }
                    }
                }
                .padding()
            }
            .background(HubTheme.canvas)
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
