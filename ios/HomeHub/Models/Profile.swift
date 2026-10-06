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
    /// The role of the account this profile belongs to ("owner", "parent" or "guest"); nil for a
    /// profile nobody signs in as, and from a server that doesn't say.
    var memberRole: String?
    var createdAt: Date?
    var updatedAt: Date?
}

extension Profile {
    /// Who a chore can be given to: children, owners and parents. Other adults (guests, and
    /// grown-ups with no account here) are left out. A server that doesn't send `memberRole`
    /// can't say what an account's role is, so its adults stay on the list.
    var canBeAssignedChores: Bool {
        if profileType == .child { return true }
        guard let memberRole else { return userId == nil ? false : true }
        return memberRole == "owner" || memberRole == "parent"
    }
}

struct ProfileInput: Codable, Sendable {
    var name: String
    var profileType: ProfileType
    var color: String
    var birthday: String?
}
