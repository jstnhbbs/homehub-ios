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

    func uploadHouseholdPhoto(data: Data, fileName: String, mimeType: String) async throws -> Household {
        try await client.uploadMultipart(
            "/api/mobile/v1/household/photo",
            fileData: data,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func removeHouseholdPhoto() async throws -> Household {
        try await client.request("/api/mobile/v1/household/photo", method: "DELETE")
    }

    func fetchHouseholdMembers() async throws -> [HouseholdMemberSummary] {
        try await client.request("/api/mobile/v1/household/members")
    }

    func updateHouseholdMemberRole(userId: String, role: HouseholdRole) async throws {
        try await client.requestVoid(
            "/api/mobile/v1/household/members/\(userId)",
            method: "PATCH",
            body: UpdateHouseholdMemberRoleRequest(role: role)
        )
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

    func deleteAccount(password: String) async throws {
        try await client.requestVoid(
            "/api/mobile/v1/account",
            method: "DELETE",
            body: DeleteAccountRequest(password: password)
        )
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

    func exportHouseholdData() async throws -> Data {
        try await client.requestData("/api/mobile/v1/household/export")
    }

    // MARK: - Hub modules

    func fetchHubModules() async throws -> HubModules {
        try await client.request("/api/mobile/v1/hub-modules")
    }

    func saveHubModules(_ modules: HubModules) async throws -> HubModules {
        try await client.request("/api/mobile/v1/hub-modules", method: "PATCH", body: modules)
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

    func saveMeal(_ input: SaveMealRequest) async throws {
        try await client.requestVoid("/api/mobile/v1/meals", method: "POST", body: input)
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

    // MARK: - Groceries

    func fetchGroceryItems() async throws -> [GroceryItem] {
        try await client.request("/api/mobile/v1/groceries")
    }

    func addGroceryItem(_ input: GroceryItemInput) async throws -> GroceryItem {
        try await client.request("/api/mobile/v1/groceries", method: "POST", body: input)
    }

    func toggleGroceryItem(id: String, checked: Bool) async throws -> GroceryItem {
        try await client.request(
            "/api/mobile/v1/groceries/\(id)",
            method: "PATCH",
            body: ToggleGroceryItemRequest(checked: checked)
        )
    }

    func deleteGroceryItem(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/groceries/\(id)", method: "DELETE")
    }

    func clearCheckedGroceryItems() async throws {
        try await client.requestVoid("/api/mobile/v1/groceries/clear-checked", method: "POST")
    }

    // MARK: - Notes

    func addHouseholdNote(_ input: HouseholdNoteInput) async throws -> HouseholdNote {
        try await client.request("/api/mobile/v1/notes", method: "POST", body: input)
    }

    func updateHouseholdNote(id: String, input: HouseholdNoteUpdateInput) async throws -> HouseholdNote {
        try await client.request("/api/mobile/v1/notes/\(id)", method: "PATCH", body: input)
    }

    func deleteHouseholdNote(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/notes/\(id)", method: "DELETE")
    }

    // MARK: - Birthdays

    func fetchBirthdays() async throws -> BirthdaysPayload {
        try await client.request("/api/mobile/v1/birthdays")
    }

    func addBirthday(_ input: BirthdayWriteInput) async throws -> BirthdayCreateResponse {
        try await client.request("/api/mobile/v1/birthdays", method: "POST", body: input)
    }

    func updateBirthday(id: String, input: BirthdayWriteInput) async throws {
        try await client.requestVoid("/api/mobile/v1/birthdays/\(id)", method: "PATCH", body: input)
    }

    func deleteBirthday(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/birthdays/\(id)", method: "DELETE")
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

    /// Imports up to 25 recipes read from a Crouton export. Text only; each created recipe's photo is
    /// sent afterwards with `uploadRecipePhoto`.
    func importCroutonRecipes(_ recipes: [CroutonRecipePayload]) async throws -> CroutonImportResponse {
        try await client.request(
            "/api/mobile/v1/recipes/import/crouton",
            method: "POST",
            body: CroutonImportRequest(recipes: recipes)
        )
    }

    func uploadRecipePhoto(recipeId: String, jpeg: Data) async throws {
        let _: IgnoredResponse = try await client.uploadMultipart(
            "/api/mobile/v1/recipes/\(recipeId)/image",
            fileData: jpeg,
            fileName: "photo.jpg",
            mimeType: "image/jpeg"
        )
    }

    func suggestRecipeTags(title: String, ingredients: [String]) async throws -> [String] {
        let response: SuggestRecipeTagsResponse = try await client.request(
            "/api/mobile/v1/recipes/suggest-tags",
            method: "POST",
            body: SuggestRecipeTagsRequest(title: title, ingredients: ingredients)
        )
        return response.tags
    }

    func updateRecipe(id: String, input: RecipeInput) async throws -> Recipe {
        try await client.request("/api/mobile/v1/recipes/\(id)", method: "PATCH", body: input)
    }

    func deleteRecipe(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/recipes/\(id)", method: "DELETE")
    }

    // MARK: - Naps

    func fetchNaps() async throws -> NapsPayload {
        try await client.request("/api/mobile/v1/naps")
    }

    // Every sleep write answers with the entry it created or changed, so the Sleep page can show
    // it straight away. `nil` means an older server that only sends `ok`; callers then refetch.

    @discardableResult
    func startNap(profileId: String) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps",
            method: "POST",
            body: NapActionRequest(action: "start", profileId: profileId)
        )
        return response.nap
    }

    @discardableResult
    func endNap(napId: String? = nil, profileId: String? = nil) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps",
            method: "POST",
            body: NapActionRequest(action: "end", profileId: profileId, napId: napId)
        )
        return response.nap
    }

    func deleteNap(id: String) async throws {
        try await client.requestVoid("/api/mobile/v1/naps/\(id)", method: "DELETE")
    }

    @discardableResult
    func createNap(profileId: String, startedAt: Date, endedAt: Date?) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps",
            method: "POST",
            body: NapActionRequest(
                action: "create",
                profileId: profileId,
                startedAt: startedAt,
                endedAt: endedAt
            )
        )
        return response.nap
    }

    @discardableResult
    func startNightSleep(profileId: String) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps",
            method: "POST",
            body: NapActionRequest(action: "startNight", profileId: profileId)
        )
        return response.nap
    }

    @discardableResult
    func createNightSleep(profileId: String, fellAsleepAt: Date, wokeUpAt: Date?) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps",
            method: "POST",
            body: NapActionRequest(
                action: "createNight",
                profileId: profileId,
                fellAsleepAt: fellAsleepAt,
                wokeUpAt: wokeUpAt
            )
        )
        return response.nap
    }

    @discardableResult
    func updateNap(id: String, startedAt: Date, endedAt: Date?) async throws -> NapLog? {
        let response: NapWriteResponse = try await client.request(
            "/api/mobile/v1/naps/\(id)",
            method: "PATCH",
            body: UpdateNapRequest(startedAt: startedAt, endedAt: endedAt)
        )
        return response.nap
    }

    // MARK: - Calendar


    func updateCalendarSettings(_ input: UpdateCalendarSettingsRequest) async throws -> Household {
        try await client.request("/api/mobile/v1/calendar/settings", method: "PATCH", body: input)
    }
}

/// For a request whose answer isn't needed, only that it worked.
private struct IgnoredResponse: Decodable, Sendable {}

private struct WeekRequest: Encodable {
    let weekStart: String
}

private struct LocalDateRequest: Encodable {
    let localDate: String
}
