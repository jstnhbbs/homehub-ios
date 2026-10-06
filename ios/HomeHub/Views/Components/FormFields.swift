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

/// The app's text field: the card color with a hairline edge, instead of the system's rounded
/// border, which is a true-black well in dark mode.
struct HubFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(HubTheme.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HubTheme.line.opacity(0.7), lineWidth: 1)
            )
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
