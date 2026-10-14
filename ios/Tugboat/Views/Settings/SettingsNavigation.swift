import SwiftUI

/// Which Settings pages are open (General, Appearance, a Layout section, …). It lives in the app
/// state rather than in the view, because choosing a theme color rebuilds every screen (see
/// `RootView`), and a stack kept in the view would drop back to the Settings list each time.
@MainActor
final class SettingsNavigationModel: ObservableObject {
    @Published var path = NavigationPath()
}

/// The navigation stack Settings pages are pushed onto, backed by `SettingsNavigationModel` so the
/// open page survives a rebuild. It observes the model itself, so opening a page redraws only this
/// stack, not every screen that watches the app state.
struct SettingsStack<Content: View>: View {
    @ObservedObject var model: SettingsNavigationModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack(path: $model.path) {
            content()
        }
    }
}
