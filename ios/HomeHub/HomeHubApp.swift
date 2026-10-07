import SwiftUI

@main
struct HomeHubApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(appState.accentPalette.textColor)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
