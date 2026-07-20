import AuthenticationServices
import UIKit

enum GoogleCalendarAuth {
    @MainActor
    static func connect(authURL: URL) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "homehub"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = PresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: APIError.serverError("Could not start Google sign-in."))
            }
        }
    }

    static func resultMessage(from callbackURL: URL?) -> (success: String?, error: String?) {
        guard let callbackURL,
              callbackURL.host == "calendar-oauth",
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            return (nil, "Google authorization was cancelled.")
        }
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if items["connected"] == "google" {
            return ("Google Calendar connected.", nil)
        }
        if items["error"] == "google-auth-denied" {
            return (nil, "Google authorization was cancelled.")
        }
        return (nil, "Google Calendar could not be connected. Try again.")
    }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
