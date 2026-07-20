import SwiftUI

enum AppTheme {
    static let darkModeKey = "homehub.darkMode"

    static var isDarkMode: Bool {
        UserDefaults.standard.bool(forKey: darkModeKey)
    }

    static func setDarkMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: darkModeKey)
    }

    static var preferredColorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
}
