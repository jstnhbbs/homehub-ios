import SwiftUI

/// Reminds someone whose email address is not confirmed yet, and sends the link again. It lives in
/// Settings only (not on Today, where it sat at the top of every launch). Nothing is blocked while
/// it shows; it goes away on its own once the address is confirmed.
struct VerifyEmailCard: View {
    @EnvironmentObject private var appState: AppState

    private enum SendState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    @State private var state: SendState = .idle

    var body: some View {
        if appState.needsEmailVerification {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.badge")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HubTheme.accentText)
                    .frame(width: 34, height: 34)
                    .background(HubTheme.sage.opacity(0.14))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm your email")
                        .font(.subheadline.weight(.heavy))
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HubTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if state != .sent {
                        Button {
                            Task { await send() }
                        } label: {
                            Text(state == .sending ? "Sending…" : "Send confirmation link")
                        }
                        .buttonStyle(HubButtonStyle(emphasis: .secondary, size: .small))
                        .disabled(state == .sending)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HubTheme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Drawn inside the edge: a stroke centered on it has half outside the card, which the
            // list row it sits in clips away.
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(HubTheme.sage.opacity(0.45), lineWidth: 1.5)
            )
            .accessibilityElement(children: .contain)
        }
    }

    private var message: String {
        let email = appState.currentUser?.email ?? "your email"
        switch state {
        case .idle, .sending:
            return "\(email) isn't confirmed yet. It only takes a tap on a link."
        case .sent:
            return "We sent a link to \(email). Open it, then come back to Beacon."
        case .failed(let reason):
            return reason
        }
    }

    private func send() async {
        state = .sending
        do {
            try await appState.sendVerificationEmail()
            state = .sent
        } catch {
            // Already confirmed on another device, or too many requests: say what the server said.
            if let reason = error.userFacingMessage { state = .failed(reason) } else { state = .idle }
            await appState.refreshSession()
        }
    }
}
