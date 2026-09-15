import Foundation

@MainActor
final class BirthdaysViewModel: ObservableObject {
    @Published var items: [BirthdayItem] = []
    @Published var profiles: [Profile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var appState: AppState?

    func bind(to appState: AppState) {
        self.appState = appState
    }

    var canManage: Bool {
        appState?.canManageHousehold ?? false
    }

    var timezone: TimeZone {
        appState?.household.flatMap { TimeZone(identifier: $0.timezone) } ?? .current
    }

    var today: String {
        DateHelpers.localDateIn(timezone: timezone)
    }

    var nextBirthday: BirthdayItem? {
        items.first
    }

    var soonCount: Int {
        items.filter { $0.daysUntil <= 30 }.count
    }

    var soonItems: [BirthdayItem] {
        items.filter { $0.id != nextBirthday?.id && $0.daysUntil <= 30 }
    }

    var laterItems: [BirthdayItem] {
        items.filter { $0.id != nextBirthday?.id && $0.daysUntil > 30 }
    }

    var laterGroups: [BirthdayMonthGroup] {
        BirthdayHelpers.monthGroups(from: laterItems, timezone: timezone, today: today)
    }

    var monthCounts: [Int: [BirthdayItem]] {
        Dictionary(grouping: items) { item in
            BirthdayHelpers.monthIndex(from: item.birthDate) ?? 0
        }
    }

    func canEdit(_ item: BirthdayItem) -> Bool {
        guard let appState else { return false }
        if item.source == .family {
            return canManage
        }
        guard let profileId = item.profileId else { return canManage }
        return appState.canEditProfile(profileId, profiles: profiles)
    }

    func load() async {
        guard let appState else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let birthdaysTask = appState.api.fetchBirthdays()
            async let profilesTask = appState.api.fetchProfiles()
            items = try await birthdaysTask.items
            profiles = try await profilesTask
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
        }
    }

    func createExtraPerson(name: String, birthDate: String) async -> Bool {
        guard let appState else { return false }
        do {
            let response = try await appState.api.addBirthday(
                BirthdayWriteInput(name: name, birthDate: birthDate)
            )
            items = response.items
            await appState.refreshDashboard()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func saveProfileBirthday(profile: Profile, birthDate: String?) async -> Bool {
        guard let appState else { return false }
        do {
            _ = try await appState.api.updateProfile(
                id: profile.id,
                input: ProfileInput(
                    name: profile.name,
                    profileType: profile.profileType,
                    color: profile.color,
                    birthday: birthDate
                )
            )
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func updateExtraPerson(_ item: BirthdayItem, name: String, birthDate: String) async -> Bool {
        guard let appState else { return false }
        do {
            try await appState.api.updateBirthday(
                id: item.id,
                input: BirthdayWriteInput(
                    name: name,
                    birthDate: birthDate,
                    profileId: item.profileId,
                    notes: item.notes,
                    giftIdeas: item.giftIdeas,
                    notifyDaysBefore: item.notifyDaysBefore
                )
            )
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }

    func delete(_ item: BirthdayItem) async -> Bool {
        guard let appState else { return false }
        do {
            if item.source == .profile, let profile = profiles.first(where: { $0.id == item.id }) {
                return await saveProfileBirthday(profile: profile, birthDate: nil)
            }
            try await appState.api.deleteBirthday(id: item.id)
            await load()
            await appState.refreshDashboard()
            return true
        } catch {
            if let message = error.userFacingMessage {
                errorMessage = message
            }
            return false
        }
    }
}
