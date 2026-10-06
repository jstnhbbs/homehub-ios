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

private struct AppIconPickerLink: View {
    @State private var selectedPalette = AccentPalette.currentAppIconPalette

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
            selectedPalette = .currentAppIconPalette
        }
    }
}

private struct AppIconPickerView: View {
    @State private var selectedPalette = AccentPalette.currentAppIconPalette
    @State private var changingTo: AccentPalette?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(AccentPalette.allCases) { palette in
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
                                    .foregroundStyle(HubTheme.sage)
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
            selectedPalette = .currentAppIconPalette
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

    private func select(_ palette: AccentPalette) {
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
    var palette: AccentPalette
    var size: CGFloat

    var body: some View {
        Image(palette.appIconPreviewAssetName)
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

    var alternateAppIconName: String? {
        switch self {
        case .sage: nil
        case .ocean: "BeaconOcean"
        case .clay: "BeaconClay"
        case .plum: "BeaconPlum"
        case .slate: "BeaconSlate"
        case .forest: "BeaconForest"
        case .teal: "BeaconTeal"
        case .indigo: "BeaconIndigo"
        case .rose: "BeaconRose"
        case .ochre: "BeaconOchre"
        }
    }

    var appIconPreviewAssetName: String {
        // Named for the palette's saved name, so renaming the colors didn't touch the art.
        "AppIcon\(rawValue.capitalized)Preview"
    }

    static var currentAppIconPalette: AccentPalette {
        let currentName = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateAppIconName == currentName } ?? .sage
    }
}
