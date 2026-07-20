import Foundation

enum HouseholdRoles {
    static func canManageHousehold(role: HouseholdRole) -> Bool {
        role == .owner || role == .parent
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
}
