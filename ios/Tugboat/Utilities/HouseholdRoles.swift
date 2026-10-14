import Foundation

enum HouseholdRoles {
    static func canManageHousehold(role: HouseholdRole) -> Bool {
        role == .owner || role == .parent
    }

    static func isOwner(role: HouseholdRole) -> Bool {
        role == .owner
    }

    static func isGuest(role: HouseholdRole) -> Bool {
        role == .guest
    }

    static func roleLabel(_ role: HouseholdRole) -> String {
        switch role {
        case .owner: "Owner"
        case .parent: "Parent"
        case .guest: "Guest"
        }
    }

    static func assignableRoles(for actorRole: HouseholdRole) -> [HouseholdRole] {
        switch actorRole {
        case .owner: [.owner, .parent, .guest]
        case .parent: [.parent, .guest]
        case .guest: []
        }
    }

    static func canChangeRole(
        actorRole: HouseholdRole,
        actorUserId: String,
        targetUserId: String,
        targetRole: HouseholdRole,
        nextRole: HouseholdRole,
        ownerCount: Int
    ) -> Bool {
        guard canManageHousehold(role: actorRole) else { return false }
        guard actorUserId != targetUserId else { return false }
        if targetRole == nextRole { return true }
        guard assignableRoles(for: actorRole).contains(nextRole) else { return false }
        if actorRole == .parent && targetRole == .owner { return false }
        if targetRole == .owner && nextRole != .owner && ownerCount <= 1 { return false }
        return true
    }

    static func editableRoles(
        actorRole: HouseholdRole,
        actorUserId: String,
        targetUserId: String,
        targetRole: HouseholdRole,
        ownerCount: Int
    ) -> [HouseholdRole] {
        assignableRoles(for: actorRole).filter { role in
            canChangeRole(
                actorRole: actorRole,
                actorUserId: actorUserId,
                targetUserId: targetUserId,
                targetRole: targetRole,
                nextRole: role,
                ownerCount: ownerCount
            )
        }
    }
}
