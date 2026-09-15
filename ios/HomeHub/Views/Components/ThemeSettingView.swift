import SwiftUI
import UIKit

struct ThemeSettingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            Picker("Mode", selection: $appState.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Picker("Theme Color", selection: $appState.accentPalette) {
                ForEach(AccentPalette.allCases) { palette in
                    Label {
                        Text(palette.label)
                    } icon: {
                        palette.swatchIcon
                    }
                    .tag(palette)
                }
            }

            AppIconPickerLink()
        } header: {
            Text("Appearance")
        } footer: {
            Text("Mode, theme color, and app icon are saved on this device.")
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
        "AppIcon\(label)Preview"
    }

    static var currentAppIconPalette: AccentPalette {
        let currentName = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateAppIconName == currentName } ?? .sage
    }
}
