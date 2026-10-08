import SwiftUI
import UIKit

struct ThemeSettingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            AppearanceModePicker()

            Toggle("True Black", isOn: $appState.usesTrueBlack)
                .disabled(appState.appearanceMode == .light)

            ThemeColorGrid()

            AppIconPickerLink()
        } header: {
            Text("Appearance")
        }
        .listRowBackground(HubTheme.tile)
    }
}

/// A miniature of a Today card (a title, a ticked row, an unticked row and the round add button) in
/// one theme color, drawn from the app's own colors so it looks as the real thing will. Put it in
/// `.environment(\.colorScheme, ...)` to see it in light or dark.
private struct MiniPage: View {
    var palette: AccentPalette
    /// Read from the app state by whoever draws the tile, so a tile is redrawn when True Black is
    /// switched (the colors it uses do not announce that themselves).
    var usesTrueBlack: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            HubTheme.canvas
            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: 22, height: 3.5)
                line(ticked: true, width: 26)
                line(ticked: false, width: 20)
            }
            .padding(9)
            Circle()
                .fill(palette.accent)
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(palette.onAccent)
                }
                .padding(7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func line(ticked: Bool, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ticked ? palette.accent : Color.clear)
                .overlay {
                    if ticked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 5, weight: .heavy))
                            .foregroundStyle(palette.onAccent)
                    } else {
                        Circle().strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                    }
                }
                .frame(width: 10, height: 10)
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: width, height: 3)
        }
    }
}

/// A tile with a name under it: ringed and bold when chosen, quiet otherwise.
private struct ChoiceTile<Preview: View>: View {
    var title: String
    var isSelected: Bool
    var ringColor: Color
    /// Width over height of the preview.
    var aspect: CGFloat
    var action: () -> Void
    @ViewBuilder var preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .aspectRatio(aspect, contentMode: .fit)
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(isSelected ? ringColor : Color.clear, lineWidth: 2.5)
                    }
                Text(title)
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : HubTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Automatic, Light or Dark, each shown as the page looks in it (Automatic is half and half).
private struct AppearanceModePicker: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mode")
            HStack(spacing: 10) {
                ForEach(AppearanceMode.allCases) { mode in
                    ChoiceTile(
                        title: mode.label,
                        isSelected: appState.appearanceMode == mode,
                        ringColor: appState.accentPalette.textColor,
                        aspect: 1.1
                    ) {
                        appState.appearanceMode = mode
                    } preview: {
                        modePreview(mode)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func modePreview(_ mode: AppearanceMode) -> some View {
        let palette = appState.accentPalette
        switch mode {
        case .light:
            MiniPage(palette: palette, usesTrueBlack: appState.usesTrueBlack).environment(\.colorScheme, .light)
        case .dark:
            MiniPage(palette: palette, usesTrueBlack: appState.usesTrueBlack).environment(\.colorScheme, .dark)
        case .system:
            GeometryReader { proxy in
                ZStack {
                    MiniPage(palette: palette, usesTrueBlack: appState.usesTrueBlack).environment(\.colorScheme, .light)
                    MiniPage(palette: palette, usesTrueBlack: appState.usesTrueBlack).environment(\.colorScheme, .dark)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: proxy.size.width / 2)
                        }
                }
            }
        }
    }
}

/// The ten theme colors as previews, five across (fewer at the largest text sizes).
private struct ThemeColorGrid: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme Color")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: DashboardMetrics.scaled(56)), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(AccentPalette.allCases) { palette in
                    ChoiceTile(
                        title: palette.label,
                        isSelected: appState.accentPalette == palette,
                        ringColor: palette.textColor,
                        aspect: 0.78
                    ) {
                        appState.accentPalette = palette
                    } preview: {
                        MiniPage(palette: palette, usesTrueBlack: appState.usesTrueBlack)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// The alternate app icons: the house in each of the ten theme colors. The ids are the theme's
/// saved ids (sage is Moss, and so on), so the icon and the theme color share a name and a
/// color. The default icon is the first (Moss); the others are `Beacon<Id>.icon`.
private enum AppIconOption: String, CaseIterable, Identifiable {
    case sage, ocean, clay, plum, slate, rosewood, teal, indigo, rose, ochre

    var id: String { rawValue }
    var label: String { AccentColorTable.labels[rawValue] ?? rawValue.capitalized }

    var alternateAppIconName: String? {
        self == .sage ? nil : "Beacon\(rawValue.capitalized)"
    }

    var previewAssetName: String { "AppIcon\(rawValue.capitalized)Preview" }

    static var current: AppIconOption {
        let currentName = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateAppIconName == currentName } ?? .sage
    }
}

private struct AppIconPickerLink: View {
    @State private var selectedPalette = AppIconOption.current

    var body: some View {
        NavigationLink {
            AppIconPickerView()
        } label: {
            HStack {
                Text("App Icon")
                Spacer()
                AppIconPreview(palette: selectedPalette, size: 30)
                Text(selectedPalette.label)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            selectedPalette = .current
        }
    }
}

private struct AppIconPickerView: View {
    @State private var selectedPalette = AppIconOption.current
    @State private var changingTo: AppIconOption?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(AppIconOption.allCases) { palette in
                    Button {
                        select(palette)
                    } label: {
                        HStack(spacing: 14) {
                            AppIconPreview(palette: palette, size: 52)

                            Text(palette.label)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedPalette == palette {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(HubTheme.accentText)
                            } else if changingTo == palette {
                                ProgressView()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(changingTo != nil)
                }
            } header: {
                Text("Choose an Icon")
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedPalette = .current
        }
        .alert("Couldn’t Change App Icon", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func select(_ palette: AppIconOption) {
        guard palette != selectedPalette else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Alternate app icons aren’t supported on this device."
            return
        }

        changingTo = palette
        UIApplication.shared.setAlternateIconName(palette.alternateAppIconName) { error in
            DispatchQueue.main.async {
                changingTo = nil
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    selectedPalette = palette
                }
            }
        }
    }
}

private struct AppIconPreview: View {
    var palette: AppIconOption
    var size: CGFloat

    var body: some View {
        Image(palette.previewAssetName)
            .resizable()
            .scaledToFit()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}
