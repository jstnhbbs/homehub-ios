import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    /// Whether the welcome tour has been shown (or skipped) on this device.
    @AppStorage(WelcomeTourPolicy.seenKey) private var welcomeTourSeen = false
    @AppStorage(PermissionsSetupView.seenKey) private var permissionsSetupSeen = false
    @State private var showingPermissionsSetup = false

    var body: some View {
        Group {
            if appState.isBootstrapping || appState.auth.isLoading {
                TugboatLoadingIndicator()
                    .accessibilityLabel("Tugboat is loading")
            } else if !appState.auth.isSignedIn {
                if WelcomeTourPolicy.shouldShow(seen: welcomeTourSeen, isSignedIn: false) {
                    WelcomeTourView { welcomeTourSeen = true }
                        .transition(.opacity)
                } else {
                    SignInView()
                }
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                HubView()
                    .id("\(appState.accentPalette.rawValue)-\(appState.backgroundStyle.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubTheme.canvas)
        // Dragging any scrolling screen or sheet puts the keyboard away. Set once here, it reaches all of them.
        .scrollDismissesKeyboard(.interactively)
        .tint(appState.accentPalette.textColor)
        // Settings on the phone is a sheet. It lives here, above the hub that is rebuilt whenever the theme color
        // changes, so choosing a color does not close it.
        .sheet(isPresented: $appState.showingSettingsSheet) {
            SettingsStack(model: appState.settingsNavigation) {
                SettingsView(presentation: .pushed)
                    .hubPageBackground()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { appState.showingSettingsSheet = false }
                        }
                    }
            }
            .environmentObject(appState)
            .tint(appState.accentPalette.textColor)
            // A sheet is its own view controller and keeps the style it was shown with, so choosing Light or Dark
            // in Appearance changed the app behind it but not the page you were on until it was reopened.
            .preferredColorScheme(appState.appearanceMode.colorScheme)
            // The colors are read again, and the navigation bar's title takes the new style, only when the stack is
            // rebuilt; it reopens on the same page because its path lives in `settingsNavigation`.
            .id("\(appState.appearanceMode.rawValue)-\(appState.accentPalette.rawValue)-\(appState.backgroundStyle.rawValue)")
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            if let notice = appState.notice {
                NoticeBanner(message: notice) { appState.dismissNotice() }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.notice)
        .animation(.easeInOut(duration: 0.25), value: welcomeTourSeen)
        // Someone already signed in (an update, a restored session) has no use for the tour, now or after a later
        // sign-out.
        .task(id: appState.auth.isSignedIn) {
            if WelcomeTourPolicy.shouldMarkSeen(seen: welcomeTourSeen, isSignedIn: appState.auth.isSignedIn) {
                welcomeTourSeen = true
            }
        }
        // Once, after signing in and setting up a household: explain what the device permissions are for and let the
        // person allow them. Someone who has already answered every one (an update, a restored session) never sees it.
        .task(id: "\(appState.auth.isSignedIn)-\(appState.needsOnboarding)-\(appState.isBootstrapping)") {
            guard appState.auth.isSignedIn, !appState.needsOnboarding, !appState.isBootstrapping, !permissionsSetupSeen else { return }
            if await PermissionsSetupView.hasUnaskedPermission(in: appState) {
                showingPermissionsSetup = true
            } else {
                permissionsSetupSeen = true
            }
        }
        .fullScreenCover(isPresented: $showingPermissionsSetup) {
            PermissionsSetupView {
                permissionsSetupSeen = true
                showingPermissionsSetup = false
            }
            .environmentObject(appState)
            .tint(appState.accentPalette.textColor)
            .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
        .onOpenURL { url in
            guard let destination = WidgetRoute.destination(from: url) else { return }
            appState.pendingWidgetRecipeId = nil
            if let recipeId = WidgetRoute.recipeId(from: url), FoodHubSection.recipes.isVisible(in: appState.hubModules) {
                appState.pendingFoodSection = .recipes
                appState.pendingWidgetRecipeId = recipeId
            }
            NotificationResponder.requestOpen(destination)
            appState.openPendingNotificationDestination()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, appState.auth.isSignedIn else { return }
            Task {
                // A widget may have checked something off or ended a sleep while the app was away.
                await appState.flushPendingWidgetActions()
                await appState.refreshForWidgetWrites()
                await appState.refreshHousehold()
                // Someone who went to their mail app to confirm their address comes back here.
                if appState.needsEmailVerification { await appState.refreshSession() }
            }
        }
        .task(id: appState.auth.isSignedIn) {
            guard appState.auth.isSignedIn else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                await appState.refreshDashboard()
            }
        }
    }
}

private struct TugboatLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.regular)
            .tint(HubTheme.accentText)
            .frame(width: 44, height: 44)
    }
}

/// A failure the person should know about, over whatever screen they are on. Tap to dismiss; it
/// also goes away by itself.
private struct NoticeBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: 520, alignment: .leading)
                .background(Color.red.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double tap to dismiss")
        .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
    }
}
