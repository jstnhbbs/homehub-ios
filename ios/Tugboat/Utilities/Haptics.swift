import UIKit

/// The app's few haptic feelings, so every screen taps the same way. Generators are kept and prepared so the
/// first tap isn't late.
///
/// - `tap`: a light tap for pressing a button.
/// - `select`: a tick for moving between tabs and options.
/// - `check`: a firmer thump for ticking something off.
/// - `uncheck`: a soft tap for putting it back.
/// - `success` / `warning`: the system's notification patterns.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred() }
    static func select() { selection.selectionChanged() }
    static func check() { medium.impactOccurred() }
    static func uncheck() { light.impactOccurred(intensity: 0.6) }
    static func success() { notification.notificationOccurred(.success) }
    static func warning() { notification.notificationOccurred(.warning) }

    /// A tick for ticking something on or off.
    static func toggled(on: Bool) { on ? check() : uncheck() }

    /// Wakes the engines before a gesture that is about to need them.
    static func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
    }
}
