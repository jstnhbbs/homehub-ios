import SwiftUI

@main
struct HomeHubApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(appState.accentPalette.accent)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
