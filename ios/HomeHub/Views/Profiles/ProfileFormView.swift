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
    var onSubmit: (ProfileInput) async -> Bool

    @State private var name = ""
    @State private var profileType: ProfileType = .child
    @State private var color = ProfileColors.options[2].value
    @State private var hasBirthday = false
    @State private var birthdayDate = Date.now
    @State private var isSaving = false

    private var isLinkedAccount: Bool {
        profile?.userId != nil
    }

    private var maxBirthdayDate: Date {
        BirthdayHelpers.maxBirthdayDate(timezone: timezone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if includeName {
                FormField(label: "Name") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
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
                    FormField(label: "Profile type") {
                        Picker("Profile type", selection: $profileType) {
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

            ProfileColorPickerView(selectedColor: $color)

            Button(submitLabel) {
                Task {
                    isSaving = true
                    defer { isSaving = false }
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
            .buttonStyle(.borderedProminent)
            .tint(HubTheme.sage)
            .disabled(isSaving || (includeName && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
        .onAppear(perform: populate)
        .onChange(of: profile?.id) { _, _ in populate() }
    }

    private func populate() {
        guard let profile else {
            name = ""
            profileType = .child
            color = ProfileColors.options[2].value
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
