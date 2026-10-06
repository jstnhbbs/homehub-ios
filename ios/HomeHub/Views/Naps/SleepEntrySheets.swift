import SwiftUI

/// "Add past sleep": one sheet for both kinds of entry, so the Sleep page itself carries no forms.
struct AddSleepSheet: View {
    @Environment(\.dismiss) private var dismiss

    let childProfiles: [Profile]
    /// Each returns an error message to show, or nil once the server has accepted the entry.
    let addNap: (String, Date, Date?) async -> String?
    let addNight: (String, Date, Date?) async -> String?

    private enum Kind: String, CaseIterable, Identifiable {
        case nap = "Nap"
        case night = "Night"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .nap
    @State private var selectedProfileId: String
    @State private var startedAt = Date.now
    @State private var endedAt = Date.now
    @State private var includeEndTime = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        childProfiles: [Profile],
        addNap: @escaping (String, Date, Date?) async -> String?,
        addNight: @escaping (String, Date, Date?) async -> String?
    ) {
        self.childProfiles = childProfiles
        self.addNap = addNap
        self.addNight = addNight
        _selectedProfileId = State(initialValue: childProfiles.first?.id ?? "")
    }

    private var startLabel: String { kind == .night ? "Fell asleep" : "Start time" }
    private var endLabel: String { kind == .night ? "Woke up" : "End time" }
    private var endToggleLabel: String { kind == .night ? "Set wake time" : "Set end time" }
    private var resolvedEnd: Date? { includeEndTime ? endedAt : nil }
    private var isValid: Bool {
        !selectedProfileId.isEmpty && NapHelpers.isValidSleepRange(startedAt: startedAt, endedAt: resolvedEnd)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if childProfiles.isEmpty {
                        EmptyStateView(text: "Add a child profile in Settings to log sleep.")
                    } else {
                        Picker("Kind", selection: $kind) {
                            ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("Child")
                            Spacer()
                            Picker("Child", selection: $selectedProfileId) {
                                ForEach(childProfiles) { Text($0.name).tag($0.id) }
                            }
                            .labelsHidden()
                        }

                        DatePicker(startLabel, selection: $startedAt, displayedComponents: [.date, .hourAndMinute])

                        Toggle(endToggleLabel, isOn: $includeEndTime)

                        if includeEndTime {
                            DatePicker(endLabel, selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                        } else {
                            Text(kind == .night
                                ? "Leave unset if they're still asleep. Add the wake time later."
                                : "Leave unset if the nap is still going.")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }

                        if includeEndTime, !isValid {
                            Text("\(endLabel) must be after \(startLabel.lowercased()).")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.red)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task {
                                isSaving = true
                                errorMessage = nil
                                let failure = kind == .night
                                    ? await addNight(selectedProfileId, startedAt, resolvedEnd)
                                    : await addNap(selectedProfileId, startedAt, resolvedEnd)
                                if let failure {
                                    errorMessage = failure
                                    isSaving = false
                                } else {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(.white) }
                                Text(saveTitle)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .primary))
                        .disabled(!isValid || isSaving)
                    }
                }
                .padding()
            }
            .background(HubTheme.canvas)
            .navigationTitle("Add past sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // A refusal stays on screen only until the person changes something to address it.
            .onChange(of: selectedProfileId) { _, _ in errorMessage = nil }
            .onChange(of: includeEndTime) { _, _ in errorMessage = nil }
            .onChange(of: endedAt) { _, _ in errorMessage = nil }
            .onChange(of: startedAt) { _, newValue in
                errorMessage = nil
                // Keep the end after the start so toggling it on starts from a sensible value.
                if endedAt <= newValue { endedAt = newValue.addingTimeInterval(kind == .night ? 8 * 3600 : 3600) }
            }
            .onChange(of: kind) { _, _ in
                errorMessage = nil
                endedAt = startedAt.addingTimeInterval(kind == .night ? 8 * 3600 : 3600)
            }
            .onAppear {
                endedAt = startedAt.addingTimeInterval(3600)
            }
        }
    }

    private var saveTitle: String {
        switch (kind, includeEndTime) {
        case (.night, false): "Start bedtime"
        case (.night, true): "Add night sleep"
        case (.nap, false): "Start nap"
        case (.nap, true): "Add nap"
        }
    }
}

/// Edit or delete one logged nap or night. Opens from a timeline block or a row in the day's list.
struct SleepEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let nap: NapLog
    let profile: Profile?
    let timezone: TimeZone
    /// Each returns an error message to show, or nil once the server has accepted the change.
    let saveAction: (Date, Date?) async -> String?
    let deleteAction: () async -> String?

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var includeEndTime: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        nap: NapLog,
        profile: Profile?,
        timezone: TimeZone,
        saveAction: @escaping (Date, Date?) async -> String?,
        deleteAction: @escaping () async -> String?
    ) {
        self.nap = nap
        self.profile = profile
        self.timezone = timezone
        self.saveAction = saveAction
        self.deleteAction = deleteAction
        _startedAt = State(initialValue: nap.startedAt)
        _endedAt = State(initialValue: nap.endedAt ?? nap.startedAt.addingTimeInterval(3600))
        _includeEndTime = State(initialValue: nap.endedAt != nil)
    }

    private var isNight: Bool { nap.kind == "night" }
    private var resolvedEnd: Date? { includeEndTime ? endedAt : nil }
    private var isValid: Bool { NapHelpers.isValidSleepRange(startedAt: startedAt, endedAt: resolvedEnd) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ProfileAvatarView(name: profile?.name ?? "?", avatar: profile?.avatar, color: profile?.color ?? "", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.name ?? "Child").font(.headline)
                            Text(isNight ? "Night sleep" : "Nap")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(HubTheme.muted)
                        }
                    }

                    DatePicker(isNight ? "Fell asleep" : "Start time", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])

                    Toggle(isNight ? "Set wake time" : "Set end time", isOn: $includeEndTime)

                    if includeEndTime {
                        DatePicker(isNight ? "Woke up" : "End time", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("Leave unset if still asleep or in progress.")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(HubTheme.muted)
                    }

                    if includeEndTime, !isValid {
                        Text("End time must be after start time.")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.red)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            isSaving = true
                            errorMessage = nil
                            if let failure = await saveAction(startedAt, resolvedEnd) {
                                errorMessage = failure
                                isSaving = false
                            } else {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Save")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HubButtonStyle(emphasis: .primary))
                    .disabled(!isValid || isSaving)

                }
                .padding()
                // Room to scroll past the delete button pinned over the corner.
                .padding(.bottom, 72)
            }
            .background(HubTheme.canvas)
            .cornerDeleteButton(
                accessibilityLabel: "Delete entry",
                confirmTitle: "Delete this entry?",
                confirmButton: "Delete",
                isDisabled: isSaving
            ) {
                isSaving = true
                errorMessage = nil
                if let failure = await deleteAction() {
                    errorMessage = failure
                    isSaving = false
                } else {
                    dismiss()
                }
            }
            .navigationTitle("Edit sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
