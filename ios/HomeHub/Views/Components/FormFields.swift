import SwiftUI

struct ProfilePickerField: View {
    let profiles: [Profile]
    @Binding var profileId: String?

    var body: some View {
        Picker("Assign to", selection: Binding(
            get: { profileId ?? "" },
            set: { profileId = $0.isEmpty ? nil : $0 }
        )) {
            Text("Everyone").tag("")
            ForEach(profiles) { profile in
                Text(profile.name).tag(profile.id)
            }
        }
        .pickerStyle(.menu)
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)
            content()
        }
    }
}

enum BirthdayPickerStyle {
    case compact
    case graphical
}

struct BirthdayPickerField: View {
    let timezone: TimeZone
    let maxDate: Date
    var style: BirthdayPickerStyle = .compact
    @Binding var hasBirthday: Bool
    @Binding var birthdayDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show birthday on calendar", isOn: $hasBirthday)
                .font(.subheadline.weight(.semibold))

            if hasBirthday {
                switch style {
                case .compact:
                    DatePicker(
                        "Birthday",
                        selection: $birthdayDate,
                        in: ...maxDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                case .graphical:
                    DatePicker(
                        "Birthday",
                        selection: $birthdayDate,
                        in: ...maxDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
