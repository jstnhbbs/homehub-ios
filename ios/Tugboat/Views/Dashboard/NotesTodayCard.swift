import SwiftUI

/// The Notes card at all three sizes.
///
/// Small is the latest note and how many there are (tap to open them). Medium adds the field to leave a
/// note and a few notes below it. Large shows the notes in two columns, with a few lines of each. Pinned
/// notes come first and carry a pin.
struct NotesTodayCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openHubDestination) private var openHubDestination

    let dashboard: DashboardData
    let size: DashboardCardSize
    var fixedHeight: CGFloat?

    @StateObject private var composer = NoteComposer()
    @State private var deletingId: String?
    @State private var noteToDelete: HouseholdNote?

    private var notes: [HouseholdNote] { dashboard.notes }

    var body: some View {
        TodayCardFrame(card: .notes, fixedHeight: fixedHeight) {
            switch size {
            case .small: small
            case .medium: medium
            case .large: large
            }
        }
        .confirmationDialog(
            "Delete \(noteToDelete?.title ?? "this note")?",
            isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Note", role: .destructive) {
                guard let note = noteToDelete else { return }
                noteToDelete = nil
                Task { await delete(note) }
            }
        }
    }

    // MARK: Small

    private var small: some View {
        TodayCardSmallBody(card: .notes) {
            VStack(alignment: .leading, spacing: 8) {
                if let latest = notes.first {
                    TodayCardHeadline(
                        headline: latest.title,
                        caption: notes.count == 1 ? "1 shared note" : "\(notes.count) shared notes",
                        headlineLines: 4,
                        headlineFont: .title3.weight(.bold)
                    )
                } else {
                    TodayCardHeadline(headline: "No notes", caption: "Leave a household note")
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            composerField
            if notes.isEmpty {
                TodayCardEmptyNote(text: "Leave a household note.")
            } else {
                WholeRowsGrid(
                    items: notes,
                    minimumColumnWidth: DashboardRow<EmptyView, EmptyView>.minimumWidthWithStatus,
                    maxColumns: 2,
                    itemHeight: { _, _ in DashboardRow<EmptyView, EmptyView>.height },
                    onMore: { openHubDestination(.notes) },
                    allowsCompactRows: true
                ) { note, _ in
                    NoteRow(note: note, canDelete: appState.canManageHousehold, isDeleting: deletingId == note.id) {
                        noteToDelete = note
                    }
                }
            }
        }
    }

    // MARK: Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            composerField
            if notes.isEmpty {
                TodayCardEmptyNote(text: "Leave a household note.")
            } else {
                WholeRowsGrid(
                    items: notes,
                    minimumColumnWidth: 150,
                    maxColumns: 2,
                    itemHeight: { _, _ in NotePreviewCard.height },
                    onMore: { openHubDestination(.notes) }
                ) { note, _ in
                    NotePreviewCard(note: note, canDelete: appState.canManageHousehold, isDeleting: deletingId == note.id) {
                        noteToDelete = note
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private var composerField: some View {
        HStack(spacing: 8) {
            TextField("Add a note", text: $composer.draft)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HubTheme.tileQuiet)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .submitLabel(.done)
                .onSubmit { Task { await addNote() } }

            Button { Task { await addNote() } } label: {
                Image(systemName: composer.isSaving ? "hourglass" : "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
                    .minimumTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Note")
            .foregroundStyle(HubTheme.onAccent)
            .background(HubTheme.sage)
            .clipShape(Circle())
            .disabled(!composer.canSubmit)
        }
    }

    private func addNote() async {
        do {
            let saved = try await composer.submit { title in
                _ = try await appState.api.addHouseholdNote(HouseholdNoteInput(title: title))
            }
            if saved { await appState.refreshDashboard() }
        } catch {
            appState.report(error)
        }
    }

    private func delete(_ note: HouseholdNote) async {
        guard deletingId == nil else { return }
        deletingId = note.id
        defer { deletingId = nil }
        do {
            try await appState.api.deleteHouseholdNote(id: note.id)
            await appState.refreshDashboard()
        } catch {
            appState.report(error)
        }
    }
}

/// A note on the Large card: its title and the start of its text, with a pin if it is pinned.
private struct NotePreviewCard: View {
    let note: HouseholdNote
    let canDelete: Bool
    let isDeleting: Bool
    let onDelete: () -> Void

    static var height: CGFloat { DashboardMetrics.scaled(112) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HubTheme.accentText)
                        .padding(.top, 2)
                        .accessibilityLabel("Pinned")
                }
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            HStack(alignment: .bottom, spacing: 4) {
                Text(note.body)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HubTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if canDelete {
                    // At the bottom, so it never takes room from the title.
                    Button(action: onDelete) {
                        Image(systemName: isDeleting ? "hourglass" : "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HubTheme.muted)
                    .disabled(isDeleting)
                    .accessibilityLabel("Delete Note")
                    .padding(.bottom, -8)
                    .padding(.trailing, -8)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
