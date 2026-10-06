import SwiftUI
import UIKit

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
        .overlay(alignment: .top) {
            if let notice = appState.notice {
                NoticeBanner(message: notice) { appState.dismissNotice() }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.notice)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, appState.auth.isSignedIn else { return }
            Task {
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

private struct BeaconLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.regular)
            .tint(HubTheme.sage)
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
