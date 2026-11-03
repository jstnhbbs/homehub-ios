import Foundation

/// Background notification writes use one immutable credential snapshot. Verification and the write
/// share a deadline, so a slow connection cannot hold the notification completion handler indefinitely.
enum NotificationActionRunner {
    private struct SessionIdentity: Decodable {
        struct User: Decodable { let id: String }
        let user: User?
    }
    private struct HouseholdIdentity: Decodable { let id: String }
    private struct ChoreCompletion: Encodable {
        let choreId: String
        let periodKey: String
        let completed = true
    }
    private struct SleepEnd: Encodable {
        let action = "end"
        let napId: String
        let endedAt: Date
    }

    static func perform(_ command: NotificationCommand, recipient: NotificationRecipient?, tappedAt: Date,
                        baseURL: URL, timeout: TimeInterval = 15,
                        credentials suppliedCredentials: SessionCredentials? = nil,
                        configuration suppliedConfiguration: URLSessionConfiguration? = nil) async throws {
        guard let recipient, !recipient.userId.isEmpty, !recipient.householdId.isEmpty else {
            throw APIError.serverError("Open Tugboat to update this reminder.")
        }
        let credentials = suppliedCredentials ?? SessionCredentials(baseURL: baseURL, readOnly: true)
        guard timeout > 0, credentials.hasSession, credentials.isCurrent else { throw APIError.unauthorized }
        let configuration = suppliedConfiguration ?? URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        let client = APIClient(baseURL: baseURL, session: session, credentials: credentials)
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(timeout)) } catch { return }
            session.invalidateAndCancel()
        }
        defer { deadline.cancel(); session.invalidateAndCancel() }
        do {
            try await withTaskCancellationHandler {
                let identity: SessionIdentity? = try await client.request("/api/auth/get-session", timeout: timeout)
                guard identity?.user?.id == recipient.userId else { throw APIError.unauthorized }
                let household: HouseholdIdentity? = try await client.request("/api/mobile/v1/household", timeout: timeout)
                guard household?.id == recipient.householdId else { throw APIError.unauthorized }
                switch command {
                case .completeChore(let choreId, let periodKey, _):
                    try await client.requestVoid("/api/mobile/v1/chores/toggle", method: "POST",
                        body: ChoreCompletion(choreId: choreId, periodKey: periodKey), timeout: timeout)
                case .endSleep(let sleepId, _):
                    try await client.requestVoid("/api/mobile/v1/naps", method: "POST",
                        body: SleepEnd(napId: sleepId, endedAt: tappedAt), timeout: timeout)
                }
            } onCancel: {
                session.invalidateAndCancel()
            }
        } catch {
            // An elapsed deadline must still show the failure notification. Account changes and
            // caller cancellation stay silent, rather than notifying a newly signed-in person.
            if error.isCancellation, !Task.isCancelled, credentials.isCurrent {
                throw URLError(.timedOut)
            }
            throw error
        }
    }
}
