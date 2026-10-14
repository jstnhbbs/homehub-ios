import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("ok   \(label)") } else { failures += 1; print("FAIL \(label)") }
}
let now = Date(timeIntervalSince1970: 100_000)
let stale = now.addingTimeInterval(-7200)
check("first authorized visit fetches", WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: nil, lastAttemptAt: nil))
check("fresh reading is reused", !WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: now.addingTimeInterval(-3599), lastAttemptAt: nil))
check("hour-old reading refreshes", WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: now.addingTimeInterval(-3600), lastAttemptAt: nil))
check("failure without data waits fifteen minutes", !WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: nil, lastAttemptAt: now.addingTimeInterval(-899)))
check("failure with stale data also waits fifteen minutes", !WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: stale, lastAttemptAt: now.addingTimeInterval(-899)))
check("stale reading retries at fifteen minutes", WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: stale, lastAttemptAt: now.addingTimeInterval(-900)))
check("fresh reading still waits an hour after a forced attempt", !WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: now.addingTimeInterval(-1800), lastAttemptAt: now.addingTimeInterval(-900)))
check("backward clock adjustment does not create a retry loop", !WeatherRefreshPolicy.shouldRefresh(now: now, readingAt: stale, lastAttemptAt: now.addingTimeInterval(30)))
check("offline is a connection message", WeatherRefreshPolicy.failureMessage(for: URLError(.notConnectedToInternet)).contains("connection"))
check("timeout asks for a retry", WeatherRefreshPolicy.failureMessage(for: URLError(.timedOut)).contains("too long"))
let outage = NSError(domain: "WeatherKit", code: 503, userInfo: [NSLocalizedDescriptionKey: "Weather service unavailable"])
check("service outage is not misreported as missing WeatherKit setup", !WeatherRefreshPolicy.failureMessage(for: outage).contains("enabled"))
let entitlement = NSError(domain: "WeatherKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "App not entitled"])
check("actual entitlement failure names setup", WeatherRefreshPolicy.failureMessage(for: entitlement).contains("enabled"))
if failures > 0 { exit(1) }
print("all passed")
