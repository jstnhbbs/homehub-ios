import SwiftUI

struct ChoresView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChoresViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if viewModel.isLoading && viewModel.chores.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.groups) { group in
                                ChoreGroupCard(group: group, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if viewModel.canManage {
                addPanel
                    .frame(width: 330)
            }
        }
        .onAppear { viewModel.bind(to: appState) }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pitch in together")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(HubTheme.sage)
                Text("Chore chart")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            Spacer()
            Label("Every check helps", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(HubTheme.sunSoft)
                .clipShape(Capsule())
        }
    }

    private var addPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Add a chore", systemImage: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)
                ChoreFormView(
                    profiles: viewModel.profiles,
                    submitLabel: "Add chore"
                ) { input in
                    await viewModel.createChore(input)
                }
            }
        }
    }
}

private struct ChoreGroupCard: View {
    let group: ChoreGroup
    @ObservedObject var viewModel: ChoresViewModel

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
                        ChoreItemRow(chore: chore, groupColor: group.color, viewModel: viewModel)
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

    @State private var isChecked: Bool

    init(chore: ChoreRow, groupColor: String, viewModel: ChoresViewModel) {
        self.chore = chore
        self.groupColor = groupColor
        self.viewModel = viewModel
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
                await viewModel.toggleChore(chore)
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

            if viewModel.canManage {
                DisclosureGroup(
                    "Edit \(chore.title)",
                    isExpanded: Binding(
                        get: { viewModel.editingChoreId == chore.id },
                        set: { viewModel.editingChoreId = $0 ? chore.id : nil }
                    )
                ) {
                    ChoreFormView(
                        profiles: viewModel.profiles,
                        chore: chore,
                        submitLabel: "Save chore",
                        onSubmit: { input in
                            await viewModel.updateChore(id: chore.id, input: input)
                        },
                        onDelete: {
                            await viewModel.deleteChore(id: chore.id)
                        }
                    )
                    .padding(.top, 8)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
            }
        }
    }
}
