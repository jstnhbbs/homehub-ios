import Foundation

enum WeatherRefreshPolicy {
    static let readingLifetime: TimeInterval = 60 * 60
    static let retryDelay: TimeInterval = 15 * 60

    static func shouldRefresh(now: Date, readingAt: Date?, lastAttemptAt: Date?) -> Bool {
        // Even a stale reading must respect the retry delay after a failed fetch.
        if let lastAttemptAt, now.timeIntervalSince(lastAttemptAt) < retryDelay { return false }
        guard let readingAt else { return true }
        return now.timeIntervalSince(readingAt) >= readingLifetime
    }

    static func failureMessage(for error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut:
                return "The weather request took too long. Try again."
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Weather couldn't refresh. Check your connection and try again."
            default: break
            }
        }
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("not entitled")
            || description.localizedCaseInsensitiveContains("missing entitlement") {
            return "Weather is unavailable until WeatherKit is enabled for this app."
        }
        return "Weather couldn't refresh. Try again later."
    }
}
