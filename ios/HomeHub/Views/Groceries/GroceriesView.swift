import SwiftUI

struct GroceriesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = GroceriesViewModel()

    /// The checked-off panel sits beside the list only when the page is wide enough to leave the list
    /// about 300pt or more. Size class alone isn't enough: an iPad mini in portrait, or an iPad window
    /// squeezed beside another app, is "regular" but only a little over 590pt wide, and a fixed 330pt
    /// panel left the list too narrow to read (one word per line).
    private static let sidePanelMinimumWidth: CGFloat = 660

    var body: some View {
        GeometryReader { proxy in
            if horizontalSizeClass != .compact, proxy.size.width >= Self.sidePanelMinimumWidth {
                wideContent
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        remindersAccessCard
                        addItemCard
                        if let error = viewModel.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        groceryList
                        checkedPanel
                    }
                }
            }
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
                    remindersAccessCard
                    addItemCard
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    groceryList
                }
            }
            .frame(maxWidth: .infinity)

            checkedPanel
                .frame(width: 330)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if horizontalSizeClass != .compact {
                    Text("Groceries")
                        .font(HubTheme.pageTitle)
                }
                Text(viewModel.usesNativeReminders ? "Writing to Reminders" : "Using Beacon list")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
            Spacer()
            if !viewModel.checkedItems.isEmpty {
                Button {
                    Task { await viewModel.clearChecked() }
                } label: {
                    Label("Clear checked", systemImage: "trash")
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondaryDestructive))
                .disabled(viewModel.isWorking)
            }
        }
    }

    @ViewBuilder
    private var remindersAccessCard: some View {
        if viewModel.needsRemindersPermission {
            HubCard {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.title2)
                        .foregroundStyle(HubTheme.sage)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use your shared Reminders list")
                            .font(.headline)
                        Text("Add grocery items from Beacon straight into Apple Reminders.")
                            .font(.footnote)
                            .foregroundStyle(HubTheme.muted)
                    }
                    Spacer()
                    Button("Allow") {
                        Task { await viewModel.requestRemindersAccess() }
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .primary, size: .small))
                }
            }
        } else if viewModel.remindersDenied {
            HubCard {
                Label("Reminders access is off. Turn it on in Settings to write to your shared grocery list.", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
            }
        } else if !viewModel.reminderLists.isEmpty {
            HubCard {
                HStack(spacing: 12) {
                    Label("Reminders list", systemImage: "list.bullet")
                        .font(.headline)
                        .foregroundStyle(HubTheme.sage)
                    if viewModel.canSelectReminderList {
                        Picker("Reminders list", selection: Binding(
                            get: { viewModel.selectedReminderListId },
                            set: { viewModel.selectReminderList(id: $0) }
                        )) {
                            Text("Automatic").tag(Optional(NativeCalendarPreferenceKeys.automaticId))
                            ForEach(viewModel.reminderLists) { list in
                                Text(list.title).tag(Optional(list.id))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text(selectedReminderListTitle ?? "Owner selects list")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(1)
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    Spacer()
                }
            }
        }
    }

    private var addItemCard: some View {
        HubCard {
            HStack(spacing: 10) {
                TextField("Add milk, apples, 2 lb pasta...", text: $viewModel.newItemTitle)
                    .textFieldStyle(HubFieldStyle())
                    .onSubmit {
                        Task { await viewModel.addItem() }
                    }

                Button {
                    Task { await viewModel.addItem() }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
                .disabled(viewModel.isWorking || viewModel.newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var groceryList: some View {
        HubCard {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 180)
            } else if viewModel.uncheckedItems.isEmpty {
                EmptyStateView(text: "Nothing on the list.")
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(viewModel.uncheckedGroups, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.category.uppercased())
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(HubTheme.muted)
                            VStack(spacing: 8) {
                                ForEach(group.items) { item in
                                    GroceryItemRow(item: item) {
                                        await viewModel.toggle(item)
                                    } onDelete: {
                                        await viewModel.delete(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var checkedPanel: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Checked off", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HubTheme.sage)

                if viewModel.checkedItems.isEmpty {
                    Text(viewModel.usesNativeReminders
                        ? "Completed Reminders stay in your selected list unless you delete or clear them here."
                        : "Completed items land here until you clear them.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.checkedItems.prefix(10)) { item in
                            GroceryItemRow(item: item, compact: true) {
                                await viewModel.toggle(item)
                            } onDelete: {
                                await viewModel.delete(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedReminderListTitle: String? {
        if viewModel.selectedReminderListId == NativeCalendarPreferenceKeys.automaticId {
            return "Automatic"
        }
        guard let selectedId = viewModel.selectedReminderListId else { return nil }
        return viewModel.reminderLists.first { $0.id == selectedId }?.title
    }
}

private struct GroceryItemRow: View {
    let item: GroceryItem
    var compact = false
    let onToggle: () async -> Void
    let onDelete: () async -> Void

    @State private var isWorking = false

    var body: some View {
        Button {
            Task {
                guard !isWorking else { return }
                isWorking = true
                await onToggle()
                isWorking = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(item.checked ? HubTheme.sage : HubTheme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font((compact ? Font.subheadline : Font.body).weight(.semibold))
                        .foregroundStyle(item.checked ? HubTheme.muted : .primary)
                        .strikethrough(item.checked, color: HubTheme.muted)
                        .lineLimit(2)
                    Text(item.quantity ?? item.category)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 9 : 12)
            .background(item.checked ? HubTheme.tileQuiet : HubTheme.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await onDelete() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await onDelete() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
