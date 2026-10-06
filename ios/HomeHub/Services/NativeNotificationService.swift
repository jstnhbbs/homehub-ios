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

    /// Replaces this app's pending reminders with ones planned from the latest dashboard.
    /// `birthdaysModuleEnabled` is the household's Birthdays module toggle; turning that module
    /// off also stops its reminders.
    func scheduleDashboardReminders(from dashboard: DashboardData, birthdaysModuleEnabled: Bool = true) async {
        await refreshAccessStatus()
        guard canSchedule else {
            await removeHomeHubPendingRequests()
            return
        }

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
                dashboard: dashboard,
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

        if settings.birthdaysEnabled, birthdaysModuleEnabled {
            requests.append(contentsOf: birthdayRequests(
                items: dashboard.upcomingBirthdays,
                timezone: timezone,
                calendar: calendar
            ))
        }

        // Only what differs from what is already scheduled is touched. A refresh follows every
        // check-off and runs each minute, and almost always the plan has not changed.
        let scheduled = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
        let changes = NotificationDiff.changes(
            existing: scheduled.map(PlannedNotification.init(request:)),
            desired: requests.map(PlannedNotification.init(request:))
        )
        if !changes.remove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: changes.remove)
        }
        let toAdd = Set(changes.add)
        for request in requests.reversed() where toAdd.contains(request.identifier) {
            // Reversed so the last request wanted for an id is the one added, as `changes` assumes.
            try? await center.add(request)
        }
    }

    private func birthdayRequests(
        items: [BirthdayItem],
        timezone: TimeZone,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        BirthdayNotificationPlanner.plan(
            items: items,
            options: settings.birthdayOptions,
            timezone: timezone
        )
        .map { reminder in
            request(
                id: reminder.id,
                title: reminder.title,
                body: reminder.body,
                fireDate: reminder.fireDate,
                calendar: calendar,
                thread: "homehub.birthdays"
            )
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
        dashboard: DashboardData,
        calendar: Calendar,
        today: Date
    ) -> [UNNotificationRequest] {
        let chores = dashboard.chores
        let pendingChores = chores.filter { !$0.completed && $0.dueToday != false }
        var requests: [UNNotificationRequest] = []

        // A chore with a time of its own reminds by name, a set time before it is due. Today's
        // come from the chore list and the next few days' are sent ahead, so a 7 am chore still
        // reminds on a day the app hasn't been opened yet. The rest share the evening check-in.
        for reminder in ChoreReminderPlanner.reminders(
            today: chores,
            upcoming: dashboard.upcomingChores,
            localDate: dashboard.localDate,
            leadMinutes: settings.choreLeadMinutes,
            now: .now,
            calendar: calendar
        ) {
            requests.append(request(
                id: reminder.id,
                title: reminder.title,
                body: reminder.body,
                fireDate: reminder.fireDate,
                calendar: calendar
            ))
        }

        let untimed = pendingChores.filter { $0.dueTime == nil }
        guard !untimed.isEmpty,
              let fireDate = fireDate(today: today, minuteOfDay: settings.choreMinute, calendar: calendar) else {
            return requests
        }

        let body = "\(untimed.count) \(untimed.count == 1 ? "chore is" : "chores are") still waiting today."
        requests.append(
            request(
                id: "chores.today",
                title: "Chore check-in",
                body: body,
                fireDate: fireDate,
                calendar: calendar
            )
        )
        return requests
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
        calendar: Calendar,
        thread: String = "homehub"
    ) -> UNNotificationRequest {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.timeZone = calendar.timeZone

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = thread

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

private extension PlannedNotification {
    init(request: UNNotificationRequest) {
        let components = (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents
        self.init(
            id: request.identifier,
            title: request.content.title,
            body: request.content.body,
            thread: request.content.threadIdentifier,
            trigger: [
                components?.year, components?.month, components?.day, components?.hour, components?.minute,
            ]
            .map { $0.map(String.init) ?? "-" }
            .joined(separator: ".") + " " + (components?.timeZone?.identifier ?? "")
        )
    }
}
