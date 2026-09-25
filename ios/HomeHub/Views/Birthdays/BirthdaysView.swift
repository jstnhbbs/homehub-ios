import SwiftUI

private enum BirthdayEditor: Identifiable {
    case add
    case edit(BirthdayItem)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let item): "edit-\(item.id)"
        }
    }
}

struct BirthdaysView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = BirthdaysViewModel()
    @State private var editor: BirthdayEditor?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        content
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        content
                    }
                }
            }
        }
        .sheet(item: $editor) { editor in
            BirthdayEditorSheet(editor: editor, viewModel: viewModel)
        }
        .task(id: appState.household?.id) {
            viewModel.bind(to: appState)
            await viewModel.load()
        }
        .refreshable {
            viewModel.bind(to: appState)
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            if horizontalSizeClass != .compact {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CelebrationNaming.current)
                        .font(HubTheme.pageTitle)
                    Text(subtitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
            } else {
                Text(subtitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
            Spacer()
            if viewModel.canManage {
                Button {
                    editor = .add
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))
            }
        }
    }

    private var subtitle: String {
        if viewModel.items.isEmpty {
            return "Keep family dates in one place"
        }
        if viewModel.soonCount == 0 {
            return "\(viewModel.items.count) saved"
        }
        return "\(viewModel.items.count) saved · \(viewModel.soonCount) in the next 30 days"
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage {
            Text(error).font(.footnote).foregroundStyle(.red)
        }

        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView().frame(maxWidth: .infinity, minHeight: 240)
        } else if viewModel.items.isEmpty {
            EmptyStateView(
                text: "Add a birthday or anniversary to see what’s next and how far away it is.",
                action: viewModel.canManage ? { editor = .add } : nil
            )
        } else {
            monthStrip
            if let next = viewModel.nextBirthday {
                nextHero(next)
            }
            ringCard
            if !viewModel.soonItems.isEmpty {
                soonSection
            }
            laterSection
        }
    }

    private var monthStrip: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Year overview")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<12, id: \.self) { month in
                        let current = BirthdayHelpers.monthIndex(from: viewModel.today) == month
                        let dots = viewModel.monthCounts[month] ?? []
                        VStack(spacing: 6) {
                            Text(BirthdayHelpers.monthShortTitle(index: month, timezone: viewModel.timezone))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(current ? HubTheme.sage : HubTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            ZStack {
                                Capsule()
                                    .fill(current ? HubTheme.sage : HubTheme.line)
                                    .frame(height: 3)
                                if !dots.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(dots.prefix(3)) { item in
                                            Circle()
                                                .fill(HubTheme.profileColor(item.color))
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .offset(y: 6)
                                }
                            }
                            .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func nextHero(_ item: BirthdayItem) -> some View {
        HubCard {
            HStack(alignment: .center, spacing: 16) {
                BirthdayCountdownBadge(days: item.daysUntil, color: item.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.daysUntil == 0 ? "Today" : "Next \(item.kind.noun)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                    Text(item.name)
                        .font(.title2.weight(.semibold))
                    Text(heroDetail(item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: item.daysUntil == 0 ? "party.popper.fill" : item.kind.systemImage)
                    .font(.title2)
                    .foregroundStyle(HubTheme.sage)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.canEdit(item) {
                    editor = .edit(item)
                }
            }
        }
        // Gift ideas stay off-screen in v1; BirthdayItem.giftIdeas is already persisted.
    }

    private func heroDetail(_ item: BirthdayItem) -> String {
        detail(item)
    }

    private var ringCard: some View {
        HubCard {
            BirthdayYearRing(
                items: viewModel.items,
                today: viewModel.today,
                timezone: viewModel.timezone,
                next: viewModel.nextBirthday,
                size: horizontalSizeClass == .compact ? 320 : 380
            )
        }
    }

    private var soonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Soon (\(viewModel.soonItems.count))")
                .font(.headline.weight(.semibold))
            ForEach(viewModel.soonItems) { item in
                birthdayRow(item, emphasize: item.daysUntil <= 7)
            }
        }
    }

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.laterItems.isEmpty {
                Text("Rest of the year")
                    .font(.headline.weight(.semibold))
            }
            ForEach(viewModel.laterGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(group.title)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }
                    ForEach(group.items) { item in
                        birthdayRow(item, emphasize: false)
                    }
                }
            }
        }
    }

    private func birthdayRow(_ item: BirthdayItem, emphasize: Bool) -> some View {
        Button {
            if viewModel.canEdit(item) {
                editor = .edit(item)
            }
        } label: {
            HStack(spacing: 12) {
                BirthdayCountdownBadge(days: item.daysUntil, color: item.color, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(rowDetail(item))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.muted)
                }
                Spacer()
                Text(BirthdayHelpers.countdownLabel(daysUntil: item.daysUntil))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(emphasize ? HubTheme.sage : HubTheme.muted)
            }
            .padding(12)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canEdit(item) && !viewModel.canManage)
    }

    private func rowDetail(_ item: BirthdayItem) -> String {
        detail(item)
    }

    /// "Sep 25 · turns 6 · Profile" or "Sep 25 · 10 years · Anniversary".
    private func detail(_ item: BirthdayItem) -> String {
        var parts = [BirthdayHelpers.dateLabel(item.nextDate, timezone: viewModel.timezone)]
        if let age = item.kind.ageDetail(item.upcomingAge) {
            parts.append(age)
        }
        parts.append(sourceLabel(item))
        return parts.joined(separator: " · ")
    }

    private func sourceLabel(_ item: BirthdayItem) -> String {
        if item.kind == .anniversary { return item.kind.capitalizedNoun }
        switch item.source {
        case .profile: return "Profile"
        case .family: return "Extra person"
        }
    }
}

private struct BirthdayCountdownBadge: View {
    let days: Int
    let color: String
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .stroke(HubTheme.profileColor(color).opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.04, 1 - min(CGFloat(days) / 365, 1)))
                .stroke(HubTheme.profileColor(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text(days == 0 ? "★" : "\(days)")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                if days != 0 {
                    Text(days == 1 ? "day" : "days")
                        .font(.system(size: size * 0.14, weight: .bold))
                        .foregroundStyle(HubTheme.muted)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(BirthdayHelpers.countdownLabel(daysUntil: days))
    }
}

private struct BirthdayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let editor: BirthdayEditor
    @ObservedObject var viewModel: BirthdaysViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                BirthdayFormView(editor: editor, viewModel: viewModel) {
                    dismiss()
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        switch editor {
        case .add: "Add to \(CelebrationNaming.current)"
        case .edit(let item): "Edit \(item.kind.noun)"
        }
    }
}

private struct BirthdayFormView: View {
    let editor: BirthdayEditor
    @ObservedObject var viewModel: BirthdaysViewModel
    var onFinished: () -> Void

    @State private var name = ""
    @State private var kind: CelebrationKind = .birthday
    @State private var target: FormTarget = .newPerson
    @State private var birthdayDate = Date.now
    @State private var isSaving = false
    @State private var confirmDelete = false

    private enum FormTarget: Hashable {
        case newPerson
        case profile(String)
    }

    private var editingItem: BirthdayItem? {
        if case .edit(let item) = editor { return item }
        return nil
    }

    private var selectedProfile: Profile? {
        if case .profile(let id) = target {
            return viewModel.profiles.first { $0.id == id }
        }
        return nil
    }

    private var isProfileBirthday: Bool {
        kind == .birthday && (editingItem?.source == .profile || selectedProfile != nil)
    }

    /// A household profile's birthday is stored on the profile, so it cannot become an anniversary.
    private var canChooseKind: Bool {
        editingItem?.source != .profile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if canChooseKind {
                FormField(label: "Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(CelebrationKind.allCases, id: \.self) { option in
                            Text(option.capitalizedNoun).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if editorIsAdd, kind == .birthday {
                FormField(label: "Who") {
                    Picker("Who", selection: $target) {
                        Text("Someone else").tag(FormTarget.newPerson)
                        ForEach(viewModel.profiles.filter { $0.birthday == nil }) { profile in
                            Text(profile.name).tag(FormTarget.profile(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if !isProfileBirthday {
                FormField(label: kind == .anniversary ? "Names" : "Name") {
                    TextField(kind == .anniversary ? "Alex & Sam" : "Justin Hobbs", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            } else if let profile = selectedProfile ?? linkedProfile {
                Text(profile.name)
                    .font(.title3.weight(.semibold))
                Text("Saved on their household profile.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            } else if editingItem?.source == .family {
                Label("Extra person", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }

            FormField(label: kind == .anniversary ? "Anniversary" : "Birthday") {
                DatePicker(
                    kind.capitalizedNoun,
                    selection: $birthdayDate,
                    in: ...viewModel.maxBirthdayDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }

            Button(editorIsAdd ? "Add \(kind.noun)" : "Save \(kind.noun)") {
                Task { await save() }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || (!isProfileBirthday && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

            if editingItem != nil, viewModel.canManage || (editingItem.map(viewModel.canEdit) ?? false) {
                Button(editingItem?.source == .profile ? "Remove \(kind.noun)" : "Delete \(kind.noun)", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(isSaving)
            }
        }
        .onAppear(perform: populate)
        .alert("Remove this \(kind.noun)?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    guard let item = editingItem else { return }
                    isSaving = true
                    defer { isSaving = false }
                    if await viewModel.delete(item) {
                        onFinished()
                    }
                }
            }
        } message: {
            Text("Household members stay in the family list. Extra entries are removed from \(CelebrationNaming.current).")
        }
    }

    private var editorIsAdd: Bool {
        if case .add = editor { return true }
        return false
    }

    private var linkedProfile: Profile? {
        guard let item = editingItem, item.source == .profile else { return nil }
        return viewModel.profiles.first { $0.id == item.id }
    }

    private func populate() {
        birthdayDate = BirthdayHelpers.maxBirthdayDate(timezone: viewModel.timezone)
        switch editor {
        case .add:
            name = ""
            target = .newPerson
        case .edit(let item):
            name = item.name
            kind = item.kind
            if item.source == .profile {
                target = .profile(item.id)
            } else {
                target = .newPerson
            }
            if let date = BirthdayHelpers.birthdayDate(from: item.birthDate, timezone: viewModel.timezone) {
                birthdayDate = date
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let birthDate = BirthdayHelpers.localBirthday(from: birthdayDate, timezone: viewModel.timezone)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved: Bool
        switch editor {
        case .add:
            if kind == .birthday, let profile = selectedProfile {
                saved = await viewModel.saveProfileBirthday(profile: profile, birthDate: birthDate)
            } else {
                saved = await viewModel.createExtraPerson(name: trimmed, birthDate: birthDate, kind: kind)
            }
        case .edit(let item):
            if item.source == .profile, let profile = viewModel.profiles.first(where: { $0.id == item.id }) {
                saved = await viewModel.saveProfileBirthday(profile: profile, birthDate: birthDate)
            } else {
                saved = await viewModel.updateExtraPerson(item, name: trimmed, birthDate: birthDate, kind: kind)
            }
        }
        if saved {
            onFinished()
        }
    }
}

private extension BirthdaysViewModel {
    var maxBirthdayDate: Date {
        BirthdayHelpers.maxBirthdayDate(timezone: timezone)
    }
}
