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
}
