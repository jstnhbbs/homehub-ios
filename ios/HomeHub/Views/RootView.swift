import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isBootstrapping || appState.auth.isLoading {
                BeaconLoadingIndicator()
                    .accessibilityLabel("Beacon is loading")
            } else if !appState.auth.isSignedIn {
                SignInView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                HubView()
                    .id(appState.accentPalette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubTheme.canvas)
        .tint(appState.accentPalette.accent)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, appState.auth.isSignedIn else { return }
            Task { await appState.refreshHousehold() }
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

private struct BeaconLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.regular)
            .tint(HubTheme.sage)
            .frame(width: 44, height: 44)
    }
}
