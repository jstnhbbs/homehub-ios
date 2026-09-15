import Foundation

struct DashboardData: Codable, Sendable {
    var household: Household
    var hubModules: HubModules?
    var localDate: String
    var profiles: [Profile]
    var routineSteps: [RoutineStepRow]
    var chores: [ChoreRow]
    var meals: [Meal]
    var scheduleEvents: [ScheduleEvent]
    var calendarStatus: CalendarSyncStatus
    var snackOptions: [String]
    var snackEaten: [String]
    var naps: [NapLog]
    var groceryItems: [GroceryItem]
    var notes: [HouseholdNote]
    var upcomingBirthdays: [BirthdayItem]

    private enum CodingKeys: String, CodingKey {
        case household
        case hubModules
        case localDate
        case profiles
        case routineSteps
        case chores
        case meals
        case scheduleEvents
        case calendarStatus
        case snackOptions
        case snackEaten
        case naps
        case groceryItems
        case notes
        case upcomingBirthdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        household = try container.decode(Household.self, forKey: .household)
        hubModules = try container.decodeIfPresent(HubModules.self, forKey: .hubModules) ?? .defaults
        localDate = try container.decode(String.self, forKey: .localDate)
        profiles = try container.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        routineSteps = try container.decodeIfPresent([RoutineStepRow].self, forKey: .routineSteps) ?? []
        chores = try container.decodeIfPresent([ChoreRow].self, forKey: .chores) ?? []
        meals = try container.decodeIfPresent([Meal].self, forKey: .meals) ?? []
        scheduleEvents = try container.decodeIfPresent([ScheduleEvent].self, forKey: .scheduleEvents) ?? []
        calendarStatus = try container.decodeIfPresent(CalendarSyncStatus.self, forKey: .calendarStatus)
            ?? CalendarSyncStatus(connected: false, updatedLabel: nil, lastSyncedAt: nil)
        snackOptions = try container.decodeIfPresent([String].self, forKey: .snackOptions) ?? []
        snackEaten = try container.decodeIfPresent([String].self, forKey: .snackEaten) ?? []
        naps = try container.decodeIfPresent([NapLog].self, forKey: .naps) ?? []
        groceryItems = try container.decodeIfPresent([GroceryItem].self, forKey: .groceryItems) ?? []
        notes = try container.decodeIfPresent([HouseholdNote].self, forKey: .notes) ?? []
        upcomingBirthdays = try container.decodeIfPresent([BirthdayItem].self, forKey: .upcomingBirthdays) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(household, forKey: .household)
        try container.encodeIfPresent(hubModules, forKey: .hubModules)
        try container.encode(localDate, forKey: .localDate)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(routineSteps, forKey: .routineSteps)
        try container.encode(chores, forKey: .chores)
        try container.encode(meals, forKey: .meals)
        try container.encode(scheduleEvents, forKey: .scheduleEvents)
        try container.encode(calendarStatus, forKey: .calendarStatus)
        try container.encode(snackOptions, forKey: .snackOptions)
        try container.encode(snackEaten, forKey: .snackEaten)
        try container.encode(naps, forKey: .naps)
        try container.encode(groceryItems, forKey: .groceryItems)
        try container.encode(notes, forKey: .notes)
        try container.encode(upcomingBirthdays, forKey: .upcomingBirthdays)
    }
}

struct HouseholdNote: Codable, Identifiable, Sendable {
    let id: String
    var title: String
    var body: String
    var color: String
    var pinned: Bool
    var createdAt: Date?
    var updatedAt: Date?
}

struct HouseholdNoteInput: Codable, Sendable {
    var title: String
}
