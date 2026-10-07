import SwiftUI
import UserNotifications

@main
struct HomeHubApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Before anything else, so a button pressed on a notification while the app is closed is
        // handled when the system launches it for that.
        NotificationResponder.registerCategories()
        UNUserNotificationCenter.current().delegate = NotificationResponder.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(appState.accentPalette.textColor)
                .preferredColorScheme(appState.appearanceMode.colorScheme)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
