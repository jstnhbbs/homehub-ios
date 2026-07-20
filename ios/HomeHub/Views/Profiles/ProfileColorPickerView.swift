import SwiftUI

struct ProfileColorPickerView: View {
    @Binding var selectedColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(ProfileColors.options) { option in
                    Button {
                        selectedColor = option.value
                    } label: {
                        Circle()
                            .fill(HubTheme.profileColor(option.value))
                            .frame(width: 34, height: 34)
                            .overlay {
                                if selectedColor == option.value {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }
            }
        }
    }
}
