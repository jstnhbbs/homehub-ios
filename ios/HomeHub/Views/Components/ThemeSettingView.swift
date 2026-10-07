import SwiftUI
import UIKit

struct ThemeSettingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            ThemeColorMenu(selection: $appState.accentPalette)

            AppIconPickerLink()
        } header: {
            Text("Appearance")
        } footer: {
            Text("Beacon follows the system light and dark appearance. Theme color and app icon are saved on this device.")
        }
    }
}

private struct ThemeColorMenu: View {
    @Binding var selection: AccentPalette

    var body: some View {
        Menu {
            Picker("Theme Color", selection: $selection) {
                ForEach(AccentPalette.allCases) { palette in
                    Label {
                        Text(palette.label)
                    } icon: {
                        Image(uiImage: palette.menuSwatchImage)
                            .renderingMode(.original)
                    }
                    .tag(palette)
                }
            }
        } label: {
            HStack {
                Text("Theme Color")
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 6) {
                    selection.swatchIcon
                        .frame(width: 20, height: 20)

                    Text(selection.label)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

/// The alternate app icons. They are drawn in the colors of the original, earthier palette and
/// keep its names. They are separate from the theme colors (which have new colors and names) and
/// will change when new icon art does.
private enum AppIconOption: String, CaseIterable, Identifiable {
    case sage, ocean, clay, plum, slate, forest, teal, indigo, rose, ochre

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

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
                Text("Choose an icon")
            } footer: {
                Text("Changing the icon does not change the app’s theme color.")
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

private extension AccentPalette {
    var menuSwatchImage: UIImage {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            context.cgContext.setFillColor(UIColor(swatch).cgColor)
            context.cgContext.fillEllipse(in: rect)
            context.cgContext.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: rect)
        }.withRenderingMode(.alwaysOriginal)
    }
}
