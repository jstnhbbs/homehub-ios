import Foundation

struct Household: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var timezone: String
    var calendarSyncIntervalMinutes: Int
    var weekStartsOn: Int
    var inviteCode: String
    var guestInviteCode: String
    var snackOptions: String
    var role: HouseholdRole
    var createdAt: Date?
    var updatedAt: Date?
}

struct HouseholdMember: Codable, Sendable {
    let householdId: String
    let userId: String
    var role: HouseholdRole
    var joinedAt: Date
}

struct HouseholdMemberSummary: Codable, Identifiable, Sendable {
    let userId: String
    var role: HouseholdRole
    var name: String
    var email: String
    var joinedAt: Date

    var id: String { userId }
}

struct CreateHouseholdRequest: Codable, Sendable {
    var name: String
    var childName: String?
    var timezone: String
}

struct JoinHouseholdRequest: Codable, Sendable {
    var inviteCode: String
}

struct JoinGuestHouseholdRequest: Codable, Sendable {
    var guestInviteCode: String
}
