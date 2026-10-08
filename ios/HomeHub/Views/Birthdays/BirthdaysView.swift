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
    /// The person picked on the ring or in the list, shown in the ring's centre.
    @State private var selectedId: String?

    /// Below this width the ring and the list stack, as on a phone.
    private static let sideBySideWidth: CGFloat = 820

    var body: some View {
        GeometryReader { proxy in
            let sideBySide = horizontalSizeClass != .compact && proxy.size.width >= Self.sideBySideWidth
                && !viewModel.items.isEmpty
            if sideBySide {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    monthStrip
                    sideBySideBody(width: proxy.size.width)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    /// Ring on the left, everything else on the right; each scrolls on its own.
    private func sideBySideBody(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let next = viewModel.nextBirthday {
                        nextHero(next)
                    }
                    ringCard
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: 440)

            ScrollViewReader { reader in
                ScrollView {
                    wideList
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedId) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy) { reader.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var monthStrip: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Year Overview")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<12, id: \.self) { month in
                        let current = BirthdayHelpers.monthIndex(from: viewModel.today) == month
                        let dots = viewModel.monthCounts[month] ?? []
                        Button {
                            if let first = dots.sorted(by: { $0.daysUntil < $1.daysUntil }).first {
                                selectedId = first.id
                            }
                        } label: {
                        VStack(spacing: 6) {
                            Text(BirthdayHelpers.monthShortTitle(index: month, timezone: viewModel.timezone))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(current ? HubTheme.accentText : HubTheme.muted)
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
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(dots.isEmpty)
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
                    .foregroundStyle(HubTheme.accentText)
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
                size: horizontalSizeClass == .compact ? 320 : 380,
                selectedId: selectedId,
                onSelect: { selectedId = $0 }
            )
        }
    }

    /// Everything coming up as one continuous grid in date order. Each row already says its date,
    /// so there are no month headings to leave half-empty rows between groups.
    private var wideList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.soonItems.isEmpty {
                Text("Soon (\(viewModel.soonItems.count))")
                    .font(.headline.weight(.semibold))
                rowGrid {
                    ForEach(viewModel.soonItems) { item in
                        birthdayRow(item, emphasize: item.daysUntil <= 7)
                    }
                }
            }
            if !viewModel.laterItems.isEmpty {
                rowGrid {
                    ForEach(viewModel.laterItems) { item in
                        birthdayRow(item, emphasize: false)
                    }
                }
            }
        }
    }

    private var soonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Soon (\(viewModel.soonItems.count))")
                .font(.headline.weight(.semibold))
            rowGrid {
                ForEach(viewModel.soonItems) { item in
                    birthdayRow(item, emphasize: item.daysUntil <= 7)
                }
            }
        }
    }

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.laterItems.isEmpty {
                Text("Rest of the Year")
                    .font(.headline.weight(.semibold))
            }
            ForEach(viewModel.laterGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.subheadline.weight(.bold))
                    rowGrid {
                        ForEach(group.items) { item in
                            birthdayRow(item, emphasize: false)
                        }
                    }
                }
            }
        }
    }

    /// One column where the list is narrow (and on a phone), two where there is room.
    private func rowGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 10, alignment: .top)], spacing: 10) {
            content()
        }
    }

    /// Beside the ring, tapping a row picks that person on the ring and a pencil edits; on a phone
    /// the whole row edits, as before.
    private var rowsSelect: Bool { horizontalSizeClass != .compact && !viewModel.items.isEmpty }

    private func birthdayRow(_ item: BirthdayItem, emphasize: Bool) -> some View {
        let selects = rowsSelect
        let isSelected = selects && selectedId == item.id
        return Button {
            if selects {
                selectedId = item.id
            } else if viewModel.canEdit(item) {
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
                    .foregroundStyle(emphasize ? HubTheme.accentText : HubTheme.muted)
                if selects && viewModel.canEdit(item) {
                    Button {
                        editor = .edit(item)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(HubTheme.tileQuiet)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(item.name)")
                }
            }
            .padding(12)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HubTheme.sage, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .id(item.id)
        .disabled(!selects && !viewModel.canEdit(item) && !viewModel.canManage)
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
        case .family: return "Extra Person"
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
            BirthdayFormView(editor: editor, viewModel: viewModel) {
                dismiss()
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
    @State private var color = ProfileColors.options[0].value
    /// Until a color is picked, a new entry shows the color the server would give it from its name.
    @State private var colorTouched = false

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

    /// Wide enough for the calendar to sit beside the fields.
    private static let sideBySideWidth: CGFloat = 700

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= Self.sideBySideWidth {
                // Fields and buttons on the left, calendar on the right: everything in view.
                withDeleteButton(
                    ScrollView {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 14) {
                                fields
                                actions
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            dateField
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        // Room to scroll past the delete button in the corner.
                        .padding(EdgeInsets(top: 20, leading: 20, bottom: canDelete ? 84 : 20, trailing: 20))
                    },
                    bottomBar: false
                )
            } else {
                // The calendar is tall, so the buttons stay pinned at the bottom rather than
                // scrolling out of sight.
                withDeleteButton(
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                fields
                                dateField
                            }
                            .padding(20)
                        }
                        Divider()
                        actions
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    },
                    bottomBar: true
                )
            }
        }
        .onAppear(perform: populate)
        .onChange(of: name) { _, newName in
            if editorIsAdd, !colorTouched {
                color = ProfileColors.automatic(forName: newName.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    /// The corner trash button for this sheet. With Save pinned in a bar along the bottom it is
    /// lined up with that bar; beside the calendar on a wide sheet it sits in the corner.
    private func withDeleteButton<Content: View>(_ content: Content, bottomBar: Bool) -> some View {
        content.cornerDeleteButton(
            isShown: canDelete,
            accessibilityLabel: "\(editingItem?.source == .profile ? "Remove" : "Delete") \(kind.noun)",
            confirmTitle: "Remove this \(kind.noun)?",
            confirmButton: editingItem?.source == .profile ? "Remove" : "Delete",
            message: "Household members stay in the family list. Extra entries are removed from \(CelebrationNaming.current).",
            isDisabled: isSaving,
            insets: EdgeInsets(top: 20, leading: 20, bottom: bottomBar ? 12 : 20, trailing: 20)
        ) {
            guard let item = editingItem else { return }
            isSaving = true
            defer { isSaving = false }
            if await viewModel.delete(item) {
                onFinished()
            }
        }
    }

    private var canDelete: Bool {
        guard let item = editingItem else { return false }
        return viewModel.canManage || viewModel.canEdit(item)
    }

    private var fields: some View {
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

            // Only worth asking when a household member is still missing a birthday; otherwise
            // "Someone Else" is the one choice.
            if editorIsAdd, kind == .birthday, !profilesWithoutBirthday.isEmpty {
                FormField(label: "Who") {
                    Picker("Who", selection: $target) {
                        Text("Someone Else").tag(FormTarget.newPerson)
                        ForEach(profilesWithoutBirthday) { profile in
                            Text(profile.name).tag(FormTarget.profile(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if !isProfileBirthday {
                FormField(label: kind == .anniversary ? "Names" : "Name") {
                    TextField(kind == .anniversary ? "Alex & Sam" : "Justin Hobbs", text: $name)
                        .textFieldStyle(HubFieldStyle())
                }
                // The color on the year wheel and in the lists. Someone with a household profile
                // uses that profile's color, so there is nothing to pick for them.
                if editingItem?.profileId == nil {
                    ProfileColorPickerView(selectedColor: Binding(
                        get: { color },
                        set: { newColor in
                            color = newColor
                            colorTouched = true
                        }
                    ))
                }
            } else if let profile = selectedProfile ?? linkedProfile {
                Text(profile.name)
                    .font(.title3.weight(.semibold))
                Text("Saved on their household profile, and shown in their profile color.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            } else if editingItem?.source == .family {
                Label("Extra Person", systemImage: "person.crop.circle.badge.plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }
        }
    }

    private var dateField: some View {
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
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(editorIsAdd ? "Add \(kind.noun)" : "Save \(kind.noun)") {
                Task { await save() }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || (!isProfileBirthday && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
    }

    private var profilesWithoutBirthday: [Profile] {
        viewModel.profiles.filter { $0.birthday == nil }
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
            color = ProfileColors.automatic(forName: "")
            colorTouched = false
        case .edit(let item):
            name = item.name
            kind = item.kind
            color = item.color
            colorTouched = true
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
                saved = await viewModel.createExtraPerson(name: trimmed, birthDate: birthDate, kind: kind, color: color)
            }
        case .edit(let item):
            if item.source == .profile, let profile = viewModel.profiles.first(where: { $0.id == item.id }) {
                saved = await viewModel.saveProfileBirthday(profile: profile, birthDate: birthDate)
            } else {
                saved = await viewModel.updateExtraPerson(item, name: trimmed, birthDate: birthDate, kind: kind, color: item.profileId == nil ? color : nil)
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
