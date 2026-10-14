import SwiftUI

enum ProfileFormMode {
    case manage
    case selfEdit
}

struct ProfileFormView: View {
    var profile: Profile?
    let mode: ProfileFormMode
    let timezone: TimeZone
    var birthdayPickerStyle: BirthdayPickerStyle = .compact
    var includeName: Bool = true
    let submitLabel: String
    var accountName: String?
    /// The other people in the family, so the color picker can mark the colors they have and a new profile
    /// starts on one nobody has.
    var otherProfiles: [Profile] = []
    var editorSession: EditorSession? = nil
    var onSubmit: (ProfileInput) async -> Bool

    @State private var name = ""
    @State private var profileType: ProfileType = .child
    @State private var color = ProfileColors.options[2].value
    @State private var hasBirthday = false
    @State private var birthdayDate = Date.now
    @State private var isSaving = false
    @State private var initialDraft: Draft?

    private struct Draft: Equatable {
        var name: String
        var type: ProfileType
        var color: String
        var hasBirthday: Bool
        var birthday: Date
    }

    private var draft: Draft {
        Draft(name: name, type: profileType, color: color, hasBirthday: hasBirthday, birthday: birthdayDate)
    }

    private var isLinkedAccount: Bool {
        profile?.userId != nil
    }

    /// Who has each color (hex, lowercased, to names) among the other people.
    private var takenBy: [String: [String]] {
        Dictionary(grouping: otherProfiles, by: { $0.color.lowercased() }).mapValues { $0.map(\.name) }
    }

    private var maxBirthdayDate: Date {
        BirthdayHelpers.maxBirthdayDate(timezone: timezone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if includeName {
                FormField(label: "Name") {
                    TextField("Name", text: $name)
                        .accessibilityLabel("Name")
                        .textFieldStyle(HubFieldStyle())
                }
            }

            FormField(label: "Birthday") {
                BirthdayPickerField(
                    timezone: timezone,
                    maxDate: maxBirthdayDate,
                    style: birthdayPickerStyle,
                    hasBirthday: $hasBirthday,
                    birthdayDate: $birthdayDate
                )
            }

            if mode == .manage {
                if isLinkedAccount {
                    Text("This adult profile is linked to a parent account.")
                        .font(.caption)
                        .foregroundStyle(HubTheme.muted)
                } else {
                    FormField(label: "Profile Type") {
                        Picker("Profile Type", selection: $profileType) {
                            Text("Adult").tag(ProfileType.adult)
                            Text("Child").tag(ProfileType.child)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } else {
                Text("Birthdays appear as annual all-day events in the family calendar.")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            }

            ProfileColorPickerView(selectedColor: $color, takenBy: takenBy)

            Button(submitLabel) {
                Task {
                    guard !isSaving else { return }
                    if let editorSession, !editorSession.beginOperation() { return }
                    isSaving = true
                    defer { isSaving = false; editorSession?.endOperation() }
                    let trimmedName = (includeName ? name : (accountName ?? profile?.name ?? ""))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    let birthday = hasBirthday
                        ? BirthdayHelpers.localBirthday(from: birthdayDate, timezone: timezone)
                        : nil
                    let input = ProfileInput(
                        name: trimmedName,
                        profileType: isLinkedAccount ? .adult : profileType,
                        color: color,
                        birthday: birthday
                    )
                    _ = await onSubmit(input)
                }
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
            .disabled(isSaving || (includeName && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        .disabled(isSaving)
        .onAppear {
            guard initialDraft == nil else { return }
            populate()
            initialDraft = draft
        }
        .onChange(of: profile?.id) { _, _ in
            populate()
            initialDraft = draft
            editorSession?.updateChanges(false)
        }
        .onChange(of: draft) { _, newValue in
            if let initialDraft { editorSession?.updateChanges(newValue != initialDraft) }
        }
    }

    private func populate() {
        guard let profile else {
            name = ""
            profileType = .child
            color = ProfileColors.firstUnused(taken: otherProfiles.map(\.color))
            hasBirthday = false
            birthdayDate = maxBirthdayDate
            return
        }
        name = profile.name
        profileType = profile.profileType
        color = profile.color
        if let birthday = profile.birthday,
           let date = BirthdayHelpers.birthdayDate(from: birthday, timezone: timezone) {
            hasBirthday = true
            birthdayDate = date
        } else {
            hasBirthday = false
            birthdayDate = maxBirthdayDate
        }
    }
}
