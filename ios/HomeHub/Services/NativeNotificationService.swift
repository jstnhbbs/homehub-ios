import Foundation
import UserNotifications

enum NativeNotificationAccessStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsScheduling: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

struct HomeHubNotificationSettings: Codable, Equatable, Sendable {
    var routinesEnabled: Bool
    var choresEnabled: Bool
    var sleepEnabled: Bool
    var morningRoutineMinute: Int
    var afternoonRoutineMinute: Int
    var eveningRoutineMinute: Int
    var choreMinute: Int
    var bedtimeMinute: Int
    var napCheckMinutes: Int

    static let defaults = HomeHubNotificationSettings(
        routinesEnabled: true,
        choresEnabled: true,
        sleepEnabled: true,
        morningRoutineMinute: 7 * 60,
        afternoonRoutineMinute: 15 * 60,
        eveningRoutineMinute: 19 * 60 + 30,
        choreMinute: 17 * 60,
        bedtimeMinute: 20 * 60,
        napCheckMinutes: 90
    )
}

@MainActor
final class NativeNotificationService: ObservableObject {
    @Published private(set) var accessStatus: NativeNotificationAccessStatus = .notDetermined
    @Published var settings: HomeHubNotificationSettings {
        didSet { saveSettings() }
    }

    private let center = UNUserNotificationCenter.current()
    private let settingsKey = "homehub.notificationSettings.v1"
    private let identifierPrefix = "homehub.local."

    init() {
        self.settings = Self.loadSettings()
        Task { await refreshAccessStatus() }
    }

    var canSchedule: Bool {
        accessStatus.allowsScheduling
    }

    func refreshAccessStatus() async {
        let notificationSettings = await center.notificationSettings()
        accessStatus = Self.accessStatus(from: notificationSettings.authorizationStatus)
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAccessStatus()
        } catch {
            await refreshAccessStatus()
        }
    }

    func scheduleDashboardReminders(from dashboard: DashboardData) async {
        await refreshAccessStatus()
        await removeHomeHubPendingRequests()
        guard canSchedule else { return }

        let timezone = TimeZone(identifier: dashboard.household.timezone) ?? .current
        let weekStartsOn = dashboard.household.weekStartsOn
        var calendar = CalendarHelpers.calendar(timezone: timezone, weekStartsOn: weekStartsOn)
        calendar.timeZone = timezone

        let today = DateHelpers.dateFromLocalDate(dashboard.localDate, timezone: timezone) ?? .now
        let profilesById = Dictionary(uniqueKeysWithValues: dashboard.profiles.map { ($0.id, $0) })
        var requests: [UNNotificationRequest] = []

        if settings.routinesEnabled {
            requests.append(contentsOf: routineRequests(
                steps: dashboard.routineSteps,
                profilesById: profilesById,
                calendar: calendar,
                today: today
            ))
        }

        if settings.choresEnabled {
            requests.append(contentsOf: choreRequests(
                chores: dashboard.chores,
                calendar: calendar,
                today: today
            ))
        }

        if settings.sleepEnabled {
            requests.append(contentsOf: sleepRequests(
                dashboard: dashboard,
                profilesById: profilesById,
                calendar: calendar,
                today: today
            ))
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    private func routineRequests(
        steps: [RoutineStepRow],
        profilesById: [String: Profile],
        calendar: Calendar,
        today: Date
    ) -> [UNNotificationRequest] {
        let pendingSteps = steps.filter { !$0.completed }
        let grouped = Dictionary(grouping: pendingSteps) { step in
            RoutineNotificationKey(period: step.period, profileId: step.profileId, routineName: step.routineName)
        }

        return grouped.compactMap { key, steps in
            let minute = routineMinute(for: key.period)
            guard let fireDate = fireDate(today: today, minuteOfDay: minute, calendar: calendar) else { return nil }
            let profileName = key.profileId.flatMap { profilesById[$0]?.name }
            let title = key.routineName
            let subject = profileName.map { "\($0) has" } ?? "There are"
            let body = "\(subject) \(steps.count) routine \(steps.count == 1 ? "step" : "steps") left."
            return request(
                id: "routine.\(key.period.rawValue).\(key.profileId ?? "everyone").\(key.routineName)",
                title: title,
                body: body,
                fireDate: fireDate,
                calendar: calendar
            )
        }
    }

    private func choreRequests(
        chores: [ChoreRow],
        calendar: Calendar,
        today: Date
    ) -> [UNNotificationRequest] {
        let pendingChores = chores.filter { !$0.completed && $0.dueToday != false }
        guard !pendingChores.isEmpty,
              let fireDate = fireDate(today: today, minuteOfDay: settings.choreMinute, calendar: calendar) else {
            return []
        }

        let body = "\(pendingChores.count) \(pendingChores.count == 1 ? "chore is" : "chores are") still waiting today."
        return [
            request(
                id: "chores.today",
                title: "Chore check-in",
                body: body,
                fireDate: fireDate,
                calendar: calendar
            )
        ]
    }

    private func sleepRequests(
        dashboard: DashboardData,
        profilesById: [String: Profile],
        calendar: Calendar,
        today: Date
    ) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        let childNames = dashboard.profiles
            .filter { $0.profileType == .child }
            .map(\.name)
        if !childNames.isEmpty,
           let fireDate = fireDate(today: today, minuteOfDay: settings.bedtimeMinute, calendar: calendar) {
            let body = childNames.count == 1
                ? "Time to start \(childNames[0])'s bedtime rhythm."
                : "Time to start the bedtime rhythm."
            requests.append(request(
                id: "sleep.bedtime",
                title: "Bedtime reminder",
                body: body,
                fireDate: fireDate,
                calendar: calendar
            ))
        }

        for nap in dashboard.naps where nap.kind == "nap" && nap.endedAt == nil {
            guard let fireDate = calendar.date(byAdding: .minute, value: settings.napCheckMinutes, to: nap.startedAt),
                  fireDate > .now else { continue }
            let name = profilesById[nap.profileId]?.name ?? "Someone"
            requests.append(request(
                id: "sleep.nap.\(nap.id)",
                title: "Nap check",
                body: "\(name) has been resting for about \(settings.napCheckMinutes) minutes.",
                fireDate: fireDate,
                calendar: calendar
            ))
        }

        return requests
    }

    private func routineMinute(for period: RoutinePeriod) -> Int {
        switch period {
        case .morning:
            settings.morningRoutineMinute
        case .afternoon:
            settings.afternoonRoutineMinute
        case .evening:
            settings.eveningRoutineMinute
        }
    }

    private func fireDate(today: Date, minuteOfDay: Int, calendar: Calendar) -> Date? {
        let hour = max(0, min(23, minuteOfDay / 60))
        let minute = max(0, min(59, minuteOfDay % 60))
        guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today),
              date > .now else {
            return nil
        }
        return date
    }

    private func request(
        id: String,
        title: String,
        body: String,
        fireDate: Date,
        calendar: Calendar
    ) -> UNNotificationRequest {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.timeZone = calendar.timeZone

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "homehub"

        return UNNotificationRequest(
            identifier: identifierPrefix + stableIdentifier(id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func stableIdentifier(_ value: String) -> String {
        value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber || character == "." || character == "-" ? character : "-"
            }
            .reduce(into: "") { partial, character in
                if partial.last == "-" && character == "-" { return }
                partial.append(character)
            }
    }

    private func removeHomeHubPendingRequests() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private static func loadSettings() -> HomeHubNotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: "homehub.notificationSettings.v1"),
              let settings = try? JSONDecoder().decode(HomeHubNotificationSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    private static func accessStatus(from status: UNAuthorizationStatus) -> NativeNotificationAccessStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .notDetermined
        }
    }
}

private struct RoutineNotificationKey: Hashable {
    let period: RoutinePeriod
    let profileId: String?
    let routineName: String
}
