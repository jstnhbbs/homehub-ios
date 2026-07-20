import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppTheme.darkModeKey) private var isDarkMode = false

    var body: some View {
        Group {
            if appState.isBootstrapping || appState.auth.isLoading {
                ProgressView("Loading Home Hub…")
            } else if !appState.auth.isSignedIn {
                SignInView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                HubView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubTheme.canvas)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
