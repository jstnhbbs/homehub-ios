import SwiftUI

/// Whether Porchlight follows the device's light and dark setting or is held to one of them. Saved on
/// the device, like the theme color.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// What to hand `preferredColorScheme`: nil leaves the choice to the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
