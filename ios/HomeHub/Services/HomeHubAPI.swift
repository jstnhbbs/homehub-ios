import Foundation

@MainActor
final class HomeHubAPI: ObservableObject {
    private let client: APIClient

    init(baseURL: URL) {
        self.client = APIClient(baseURL: baseURL)
    }

    // MARK: - Household

    func fetchHousehold() async throws -> Household? {
        try await client.request("/api/mobile/v1/household")
    }

    func createHousehold(_ input: CreateHouseholdRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/household", method: "POST", body: input)
    }

    func joinHousehold(_ input: JoinHouseholdRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/household/join", method: "POST", body: input)
    }

    func joinHouseholdAsGuest(_ input: JoinGuestHouseholdRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/household/join-guest", method: "POST", body: input)
    }

    func fetchHouseholdMembers() async throws -> [HouseholdMemberSummary] {
        try await client.request("/api/mobile/v1/household/members")
    }

    func removeGuestMember(userId: String) async throws {
        try await client.requestVoid("/api/mobile/v1/household/members/\(userId)", method: "DELETE")
    }

    // MARK: - Dashboard

    func fetchDashboard() async throws -> DashboardData {
        try await client.request("/api/mobile/v1/dashboard")
    }

    // MARK: - Profiles

    func fetchProfiles() async throws -> [Profile] {
        try await client.request("/api/mobile/v1/profiles")
    }

    func addProfile(_ input: ProfileInput) async throws -> Profile {
        try await client.request("/api/mobile/v1/profiles", method: "POST", body: input)
    }

    func updateProfile(id: String, input: ProfileInput) async throws -> Profile {
        try await client.request("/api/mobile/v1/profiles/\(id)", method: "PATCH", body: input)
    }

    func uploadProfilePhoto(id: String, data: Data, fileName: String, mimeType: String) async throws -> Profile {
        try await client.uploadMultipart(
            "/api/mobile/v1/profiles/\(id)/photo",
            fileData: data,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func removeProfilePhoto(id: String) async throws -> Profile {
        try await client.request("/api/mobile/v1/profiles/\(id)/photo", method: "DELETE")
    }

    // MARK: - Account

    func fetchAccount() async throws -> AccountData {
        try await client.request("/api/mobile/v1/account")
    }

    func updateAccountName(_ name: String) async throws -> AccountData {
        try await client.request("/api/mobile/v1/account", method: "PATCH", body: UpdateAccountRequest(name: name))
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        try await client.request(
            "/api/mobile/v1/account/change-password",
            method: "POST",
            body: ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword,
                revokeOtherSessions: true
            )
        )
    }

    func changeEmail(_ newEmail: String) async throws -> ChangeEmailResponse {
        try await client.request(
            "/api/mobile/v1/account/change-email",
            method: "POST",
            body: ChangeEmailRequest(newEmail: newEmail)
        )
    }

    // MARK: - Routines

    func fetchRoutines() async throws -> [Routine] {
        try await client.request("/api/mobile/v1/routines")
    }

    func addRoutine(_ input: RoutineInput) async throws -> Routine {
        try await client.request("/api/mobile/v1/routines", method: "POST", body: input)
    }

    func updateRoutine(id: String, input: RoutineInput) async throws -> Routine {
        try await client.request("/api/mobile/v1/routines/\(id)", method: "PATCH", body: input)
    }

    func deleteRoutine(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/routines/\(id)", method: "DELETE")
    }

    func toggleRoutineStep(_ input: ToggleRoutineStepRequest) async throws {
        try await client.requestVoid("/api/mobile/v1/routines/toggle-step", method: "POST", body: input)
    }

    // MARK: - Chores

    func fetchChores(localDate: String, scope: String = "due") async throws -> [ChoreRow] {
        try await client.request("/api/mobile/v1/chores?localDate=\(localDate)&scope=\(scope)")
    }

    func fetchAllChores(localDate: String) async throws -> [ChoreRow] {
        try await fetchChores(localDate: localDate, scope: "all")
    }

    func addChore(_ input: ChoreInput) async throws -> Chore {
        try await client.request("/api/mobile/v1/chores", method: "POST", body: input)
    }

    func updateChore(id: String, input: ChoreInput) async throws -> Chore {
        try await client.request("/api/mobile/v1/chores/\(id)", method: "PATCH", body: input)
    }

    func deleteChore(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/chores/\(id)", method: "DELETE")
    }

    func toggleChore(_ input: ToggleChoreRequest) async throws {
        try await client.requestVoid("/api/mobile/v1/chores/toggle", method: "POST", body: input)
    }

    // MARK: - Meals

    func fetchMeals(weekStart: String) async throws -> [Meal] {
        try await client.request("/api/mobile/v1/meals?weekStart=\(weekStart)")
    }

    func saveMeal(_ input: SaveMealRequest) async throws -> Meal {
        try await client.request("/api/mobile/v1/meals", method: "POST", body: input)
    }

    func clearMealWeek(weekStart: String) async throws {
        try await client.requestVoid("/api/mobile/v1/meals/clear-week", method: "POST", body: WeekRequest(weekStart: weekStart))
    }

    func copyPreviousMealWeek(weekStart: String) async throws {
        try await client.requestVoid("/api/mobile/v1/meals/copy-previous-week", method: "POST", body: WeekRequest(weekStart: weekStart))
    }

    // MARK: - Snacks

    func saveSnackOptions(_ input: SaveSnackOptionsRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/snacks/options", method: "POST", body: input)
    }

    func toggleSnack(_ input: ToggleSnackRequest) async throws {
        try await client.requestVoid("/api/mobile/v1/snacks/toggle", method: "POST", body: input)
    }

    func resetSnackChecklist(localDate: String) async throws {
        try await client.requestVoid("/api/mobile/v1/snacks/reset", method: "POST", body: LocalDateRequest(localDate: localDate))
    }

    // MARK: - Recipes

    func fetchRecipes() async throws -> [Recipe] {
        try await client.request("/api/mobile/v1/recipes")
    }

    func fetchRecipe(id: String) async throws -> Recipe {
        try await client.request("/api/mobile/v1/recipes/\(id)")
    }

    func addRecipe(_ input: RecipeInput) async throws -> Recipe {
        try await client.request("/api/mobile/v1/recipes", method: "POST", body: input)
    }

    func importRecipe(_ input: ImportRecipeRequest) async throws -> Recipe {
        try await client.request("/api/mobile/v1/recipes/import", method: "POST", body: input)
    }

    func updateRecipe(id: String, input: RecipeInput) async throws -> Recipe {
        try await client.request("/api/mobile/v1/recipes/\(id)", method: "PATCH", body: input)
    }

    func deleteRecipe(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/recipes/\(id)", method: "DELETE")
    }

    // MARK: - Calendar

    func fetchCalendarOccurrences(start: String, end: String, query: String = "") async throws -> [CalendarOccurrence] {
        var path = "/api/mobile/v1/calendar/events?start=\(start)&end=\(end)"
        if !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&q=\(encoded)"
        }
        return try await client.request(path)
    }

    func fetchCalendarPickerOptions() async throws -> [CalendarPickerOption] {
        try await client.request("/api/mobile/v1/calendar/calendars")
    }

    func fetchCalendarEvents(start: String, end: String) async throws -> [ScheduleEvent] {
        try await fetchCalendarOccurrences(start: start, end: end).map {
            ScheduleEvent(
                eventId: $0.eventId,
                title: $0.title,
                startsAt: $0.startsAt,
                endsAt: $0.endsAt,
                allDay: $0.allDay,
                color: $0.color,
                calendarName: $0.calendarName
            )
        }
    }

    func syncCalendar(force: Bool = false) async throws {
        let path = force ? "/api/calendar/sync?force=true" : "/api/calendar/sync"
        try await client.requestVoid(path, method: "POST")
    }

    func createCalendarEvent(_ input: CalendarEventFormInput) async throws {
        try await client.requestVoid("/api/mobile/v1/calendar/events", method: "POST", body: input)
    }

    func updateCalendarEvent(id: String, input: CalendarEventFormInput) async throws {
        try await client.requestVoid("/api/mobile/v1/calendar/events/\(id)", method: "PATCH", body: input)
    }

    func deleteCalendarEvent(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/calendar/events/\(id)", method: "DELETE")
    }

    func fetchCalendarConnections() async throws -> [CalendarConnection] {
        try await client.request("/api/mobile/v1/calendar/connections")
    }

    func fetchHouseholdCalendars() async throws -> [HouseholdCalendarOption] {
        try await client.request("/api/mobile/v1/calendar/calendar-list")
    }

    func updateCalendarSelection(calendarIds: [String]) async throws -> [HouseholdCalendarOption] {
        try await client.request(
            "/api/mobile/v1/calendar/calendar-list",
            method: "PATCH",
            body: UpdateCalendarSelectionRequest(calendarIds: calendarIds)
        )
    }

    func updateCalendarSettings(_ input: UpdateCalendarSettingsRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/calendar/settings", method: "PATCH", body: input)
    }

    func connectICloudCalendar(_ input: ConnectICloudRequest) async throws {
        let _: OkResponse = try await client.request(
            "/api/mobile/v1/calendar/connect/icloud",
            method: "POST",
            body: input
        )
    }

    func disconnectCalendar(provider: CalendarProvider) async throws {
        try await client.requestVoid("/api/mobile/v1/calendar/connect/\(provider.rawValue)", method: "DELETE")
    }

    func fetchGoogleCalendarConnectURL() async throws -> URL {
        let response: GoogleConnectURLResponse = try await client.request("/api/mobile/v1/calendar/google/connect-url")
        guard let url = URL(string: response.url) else {
            throw APIError.invalidURL
        }
        return url
    }
}

private struct WeekRequest: Encodable {
    let weekStart: String
}

private struct LocalDateRequest: Encodable {
    let localDate: String
}
