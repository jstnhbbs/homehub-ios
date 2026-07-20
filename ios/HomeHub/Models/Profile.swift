import Foundation

struct Profile: Codable, Identifiable, Sendable {
    let id: String
    let householdId: String
    var userId: String?
    var profileType: ProfileType
    var name: String
    var color: String
    var avatar: String
    var birthday: String?
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?
}

struct ProfileInput: Codable, Sendable {
    var name: String
    var profileType: ProfileType
    var color: String
    var birthday: String?
}
