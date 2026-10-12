import SwiftUI

struct ProfileColorPickerView: View {
    @Binding var selectedColor: String
    /// Who already has each color (hex value to names), so a color someone else uses is marked. It can still
    /// be chosen: with more than nine people some must share.
    var takenBy: [String: [String]] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(ProfileColors.choices) { option in
                    Button {
                        selectedColor = option.value
                    } label: {
                        Circle()
                            .fill(HubTheme.profileColor(option.value))
                            .frame(width: 34, height: 34)
                            .overlay(alignment: .bottomTrailing) {
                                if taken(option.value) != nil, selectedColor != option.value {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(HubTheme.muted)
                                        .frame(width: 15, height: 15)
                                        .background(HubTheme.tile, in: Circle())
                                        .overlay(Circle().stroke(HubTheme.line, lineWidth: 0.5))
                                        .offset(x: 3, y: 3)
                                        .accessibilityHidden(true)
                                }
                            }
                            .overlay {
                                if selectedColor == option.value {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(HubTheme.readableText(on: HubTheme.profileColor(option.value)))
                                }
                            }
                            .minimumTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(taken(option.value).map { "\(option.label), used by \($0)" } ?? option.label)
                    .accessibilityAddTraits(selectedColor == option.value ? .isSelected : [])
                }
            }
        }
    }

    private func taken(_ value: String) -> String? {
        guard let names = takenBy[value.lowercased()], !names.isEmpty else { return nil }
        return names.joined(separator: ", ")
    }
}
