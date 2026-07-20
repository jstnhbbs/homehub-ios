import SwiftUI

struct ThemeSettingView: View {
    @AppStorage(AppTheme.darkModeKey) private var isDarkMode = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.title3)
                .foregroundStyle(HubTheme.accent)
                .frame(width: 40, height: 40)
                .background(HubTheme.selectionBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Dark mode")
                    .font(.subheadline.weight(.semibold))
                Text(isDarkMode ? "On · neutral grey surfaces" : "Off · light theme")
                    .font(.caption)
                    .foregroundStyle(HubTheme.muted)
            }

            Spacer()

            Toggle("Dark mode", isOn: $isDarkMode)
                .labelsHidden()
        }
        .padding(14)
        .background(HubTheme.tileQuiet)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HubTheme.line, lineWidth: 1)
        )
    }
}
