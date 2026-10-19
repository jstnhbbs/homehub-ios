import Foundation

var failures = 0
func check(_ label: String, _ ok: Bool) {
    if ok { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}

// When it shows
check("a fresh install that isn't signed in sees the tour", WelcomeTourPolicy.shouldShow(seen: false, isSignedIn: false))
check("once seen, it doesn't come back", !WelcomeTourPolicy.shouldShow(seen: true, isSignedIn: false))
check("someone signed in never gets it unasked", !WelcomeTourPolicy.shouldShow(seen: false, isSignedIn: true))
check("signing in counts as having seen it", WelcomeTourPolicy.shouldMarkSeen(seen: false, isSignedIn: true))
check("nothing to mark once it is marked", !WelcomeTourPolicy.shouldMarkSeen(seen: true, isSignedIn: true))
check("being signed out marks nothing", !WelcomeTourPolicy.shouldMarkSeen(seen: false, isSignedIn: false))
check("signing out later doesn't bring the tour back", { let seen = WelcomeTourPolicy.shouldMarkSeen(seen: false, isSignedIn: true); return seen && !WelcomeTourPolicy.shouldShow(seen: true, isSignedIn: false) }())
check("the saved key is namespaced like the others", WelcomeTourPolicy.seenKey.hasPrefix("tugboat."))

// The pages
let all = WelcomeTourPage.pages(replay: false)
check("five pages on a first launch", all.count == 5)
check("a replay leaves out the sign-in page", WelcomeTourPage.pages(replay: true).count == 4 && !WelcomeTourPage.pages(replay: true).contains(.start))
check("the sign-in page is last", all.last == .start)
check("pages are in the order they were planned", all.map(\.rawValue) == [0, 1, 2, 3, 4])
check("every headline and sentence has words", all.allSatisfy { !$0.headline.isEmpty && !$0.detail.isEmpty && !$0.pictureDescription.isEmpty })
check("headlines are all different", Set(all.map(\.headline)).count == all.count)
check("a headline fits on two lines of a phone", all.allSatisfy { $0.headline.count <= 32 })
check("a sentence stays short enough to read at a glance", all.allSatisfy { $0.detail.count <= 110 })
check("a sentence ends with a full stop", all.allSatisfy { $0.detail.hasSuffix(".") })
check("a headline doesn't end with a full stop", all.allSatisfy { !$0.headline.hasSuffix(".") })
// Title Case: every word of three or more letters starts with a capital (short words may be lower case).
check("headlines are in Title Case", all.allSatisfy { page in
    page.headline.split(separator: " ").allSatisfy { word in
        let w = word.trimmingCharacters(in: .punctuationCharacters)
        return w.count <= 3 || w.first!.isUppercase
    }
})
check("the lock screen page describes today's design (naps, with an End button)", WelcomeTourPage.lockScreen.detail.contains("nap") && WelcomeTourPage.lockScreen.detail.contains("End Nap"))

if failures > 0 { print("\n\(failures) failed"); exit(1) }
print("\nall welcome tour checks passed")
