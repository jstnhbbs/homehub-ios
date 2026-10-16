import Foundation

enum WidgetSnapshotBuilder {
    static func make(
        dashboard: DashboardData, userId: String, palette: String,
        events: [ScheduleEvent], groceries: [GroceryItem], modules: HubModules,
        now: Date = .now
    ) -> WidgetSnapshot {
        let timezone = TimeZone(identifier: dashboard.household.timezone) ?? .current
        let today = dashboard.localDate
        func dateAt(_ time: String?) -> Date? {
            guard let time, let (hour, minute) = ChoreHelpers.hourAndMinute(time),
                  let start = DateHelpers.dateFromLocalDate(today, timezone: timezone) else { return nil }
            return DateHelpers.gregorian(in: timezone).date(byAdding: .minute, value: hour * 60 + minute, to: start)
        }
        let enabled = HubDestination.allCases.filter { $0.isVisible(in: modules) }.map(\.rawValue)
        let remaining = groceries.filter { !$0.checked }
        let dinner = dashboard.meals.first { $0.localDate == today && $0.slot == .dinner }
        let previous = WidgetStore().load()
        let imageURL = previous?.householdId == dashboard.household.id && previous?.userId == userId
            && previous?.dinner?.recipeId == dinner?.recipeId ? previous?.dinner?.imageURL : nil
        return WidgetSnapshot(
            userId: userId, householdId: dashboard.household.id, householdName: dashboard.household.name,
            timezone: dashboard.household.timezone, localDate: today, updatedAt: now,
            accentLight: AccentColorTable.light[palette] ?? "#57764C", accentDark: AccentColorTable.dark[palette] ?? "#5F8153",
            enabledDestinations: enabled,
            people: dashboard.profiles.map { .init(id: $0.id, name: $0.name, color: $0.color, isChild: $0.profileType == .child) },
            steps: enabled.contains("routines") ? dashboard.routineSteps.map { .init(id: $0.id, label: $0.label, personId: $0.profileId, period: $0.period.rawValue, completed: $0.completed) } : [],
            chores: enabled.contains("chores") ? dashboard.chores.map { .init(id: $0.id, title: $0.title, personId: $0.profileId, periodKey: $0.periodKey, dueAt: dateAt($0.dueTime), completed: $0.completed) } : [],
            events: enabled.contains("calendar") ? Array(events.prefix(100)).map { .init(id: $0.eventId, title: $0.title, start: $0.startsAt, end: $0.endsAt, allDay: $0.allDay) } : [],
            dinner: enabled.contains("meals") ? dinner.map { .init(title: $0.title, recipeId: $0.recipeId, imageURL: imageURL) } : nil,
            sleeps: enabled.contains("sleep") ? dashboard.naps.map { .init(id: $0.id, personId: $0.profileId, start: $0.startedAt, end: $0.endedAt, kind: $0.kind) } : [],
            notes: enabled.contains("notes") ? dashboard.notes.map { .init(id: $0.id, title: $0.title, body: String($0.body.prefix(2000)), pinned: $0.pinned) } : [],
            groceries: enabled.contains("groceries") ? Array(remaining.prefix(30)).map(\.title) : [],
            groceryCount: enabled.contains("groceries") ? remaining.count : 0,
            celebrations: enabled.contains("birthdays") ? dashboard.upcomingBirthdays.map { .init(id: $0.id, name: $0.name, date: $0.nextDate, years: $0.upcomingAge, isAnniversary: $0.kind == .anniversary) } : [],
            actionError: nil,
            server: AppConfig.baseURL.absoluteString
        )
    }
}
