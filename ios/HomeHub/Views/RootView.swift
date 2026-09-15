import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isBootstrapping || appState.auth.isLoading {
                BeaconLoadingMark()
                    .accessibilityLabel("Beacon is loading")
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
        .tint(appState.accentPalette.accent)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
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

private struct BeaconLoadingMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            Image(systemName: "house.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(HubTheme.sage)
                .offset(y: -2)

            Image(systemName: "checkmark")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.89, green: 0.66, blue: 0.29))
                .offset(x: -8, y: 10)
        }
        .frame(width: 96, height: 96)
    }
}
