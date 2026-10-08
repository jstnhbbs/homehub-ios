import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var draft = ""
    @State private var isSaving = false
    @State private var deletingId: String?
    @State private var editingNote: HouseholdNote?

    private var notes: [HouseholdNote] {
        appState.dashboard?.notes ?? []
    }

    private var canManage: Bool {
        appState.canManageHousehold
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                addNoteCard
                notesList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            if appState.dashboard == nil {
                await appState.refreshDashboard()
            }
        }
        .refreshable {
            await appState.refreshDashboard()
        }
        .sheet(item: $editingNote) { note in
            NoteEditorSheet(note: note) { input in
                _ = try await appState.api.updateHouseholdNote(id: note.id, input: input)
                await appState.refreshDashboard()
            } onDelete: {
                await delete(note)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if horizontalSizeClass != .compact {
                Text("Notes")
                    .font(HubTheme.pageTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            Text("Household Scratchpad")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HubTheme.muted)
        }
    }

    private var addNoteCard: some View {
        HStack(spacing: 10) {
            TextField("Add a note", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body.weight(.semibold))
                .lineLimit(1...4)
                .submitLabel(.done)
                .onSubmit {
                    Task { await addNote() }
                }

            Button {
                Task { await addNote() }
            } label: {
                Image(systemName: isSaving ? "hourglass" : "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .minimumTapTarget()
            }
            .accessibilityLabel("Add Note")
            .buttonStyle(.plain)
            .foregroundStyle(HubTheme.onAccent)
            .background(HubTheme.sage)
            .clipShape(Circle())
            .disabled(isSaving || trimmedDraft.isEmpty)
        }
        .padding(16)
        .background(HubTheme.tile)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var notesList: some View {
        if notes.isEmpty {
            ContentUnavailableView(
                "No Notes",
                systemImage: "note.text",
                description: Text("Add anything the household needs to remember.")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(HubTheme.line, lineWidth: 1)
            )
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 10, alignment: .top)], spacing: 10) {
                ForEach(notes) { note in
                    NotesPageRow(note: note, canEdit: canManage, isDeleting: deletingId == note.id) {
                        editingNote = note
                    } onDelete: {
                        await delete(note)
                    }
                }
            }
        }
    }

    private func addNote() async {
        let title = trimmedDraft
        guard !title.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await appState.api.addHouseholdNote(HouseholdNoteInput(title: title))
            draft = ""
            await appState.refreshDashboard()
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

private struct NotesPageRow: View {
    let note: HouseholdNote
    let canEdit: Bool
    let isDeleting: Bool
    let onOpen: () -> Void
    let onDelete: () async -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: note.pinned ? "pin.fill" : "note.text")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.accentText)
                    .frame(width: 30, height: 30)
                    .background(HubTheme.sage.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                    if !note.body.isEmpty {
                        Text(note.body)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HubTheme.muted)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if canEdit {
                    Button {
                        Task { await onDelete() }
                    } label: {
                        Image(systemName: isDeleting ? "hourglass" : "trash")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 36, height: 36)
                            .minimumTapTarget()
                    }
                    .accessibilityLabel("Delete Note")
                    .buttonStyle(.plain)
                    .foregroundStyle(HubTheme.muted)
                    .disabled(isDeleting)
                }
            }
            .padding(14)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HubTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(canEdit)
    }
}

private struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let note: HouseholdNote
    let onSave: (HouseholdNoteUpdateInput) async throws -> Void
    let onDelete: () async -> Void

    @State private var title: String
    @State private var noteBody: String
    @State private var pinned: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    init(
        note: HouseholdNote,
        onSave: @escaping (HouseholdNoteUpdateInput) async throws -> Void,
        onDelete: @escaping () async -> Void
    ) {
        self.note = note
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: note.title)
        _noteBody = State(initialValue: note.body)
        _pinned = State(initialValue: note.pinned)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Details", text: $noteBody, axis: .vertical)
                        .lineLimit(4...10)
                    Toggle("Pin Note", isOn: $pinned)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Delete Note", role: .destructive) {
                        confirmDelete = true
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || trimmedTitle.isEmpty)
                }
            }
            .alert("Delete this note?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        isSaving = true
                        await onDelete()
                        isSaving = false
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSave(
                HouseholdNoteUpdateInput(
                    title: trimmedTitle,
                    body: noteBody.trimmingCharacters(in: .whitespacesAndNewlines),
                    pinned: pinned
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
