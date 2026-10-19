import Foundation

/// When the welcome tour shows. Foundation only, checked in `ios/checks/welcome-tour`.
///
/// It is shown once per install, before the sign-in screen, to someone who has never signed in on this device.
/// Anyone already signed in (an update, or a restored session) is counted as having seen it, so signing out
/// later doesn't greet them with a tour about an app they use every day. It can always be replayed from
/// Settings → About.
enum WelcomeTourPolicy {
    /// The UserDefaults key that remembers the tour has been shown (or skipped).
    static let seenKey = "tugboat.welcomeTourSeen"

    static func shouldShow(seen: Bool, isSignedIn: Bool) -> Bool {
        !seen && !isSignedIn
    }

    /// Being signed in counts as having seen it.
    static func shouldMarkSeen(seen: Bool, isSignedIn: Bool) -> Bool {
        isSignedIn && !seen
    }
}

/// The screens of the welcome tour and their words. The pictures are drawn by `WelcomeTourView`, from the
/// app's own cards and widgets.
enum WelcomeTourPage: Int, CaseIterable, Identifiable, Sendable {
    case today, together, lockScreen, widgets, start

    var id: Int { rawValue }

    /// A title: Title Case, as the app's other titles are.
    var headline: String {
        switch self {
        case .today: "Your Whole Day, One Screen"
        case .together: "Check Things Off, Together"
        case .lockScreen: "Naps From the Lock Screen"
        case .widgets: "Widgets and Your Own Look"
        case .start: "Let's Go"
        }
    }

    /// A sentence: sentence case.
    var detail: String {
        switch self {
        case .today: "Routines, chores, dinner and the weather, all on the Today page."
        case .together: "Whoever is nearest ticks off a step, a chore or a snack, and everyone sees it at once."
        case .lockScreen: "Start a nap and its timer sits on your Lock Screen, with an End Nap button."
        case .widgets: "Check things off from the Home Screen without opening the app, in any of ten theme colors."
        case .start: "Make an account, or sign in to your family's."
        }
    }

    /// What a screen's VoiceOver label adds for the picture, which is otherwise hidden from VoiceOver.
    var pictureDescription: String {
        switch self {
        case .today: "A sample Today page with Routines, Chores, Food and Snacks cards."
        case .together: "A sample routine and snack list you can tap to tick off."
        case .lockScreen: "A sample Lock Screen with a nap timer and an End Nap button."
        case .widgets: "Sample Home Screen widgets and ten theme colors."
        case .start: "The Tugboat app icon."
        }
    }

    /// The pages for a first launch (all of them) or a replay from Settings (without the sign-in page).
    static func pages(replay: Bool) -> [WelcomeTourPage] {
        replay ? allCases.filter { $0 != .start } : allCases
    }
}
