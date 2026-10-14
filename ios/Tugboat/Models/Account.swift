import Foundation

struct AccountData: Codable, Sendable {
    let user: User
    let profile: Profile?
}

struct UpdateAccountRequest: Codable, Sendable {
    let name: String
}

struct DeleteAccountRequest: Codable, Sendable {
    let password: String
}

struct ChangePasswordRequest: Codable, Sendable {
    let currentPassword: String
    let newPassword: String
    let revokeOtherSessions: Bool
}

struct ChangeEmailRequest: Codable, Sendable {
    let newEmail: String
}

struct ChangePasswordResponse: Codable, Sendable {
    let user: User?
    let token: String?
}

struct ChangeEmailResponse: Codable, Sendable {
    let user: User?
    let status: Bool?
    /// True when the address changed at once, false when a confirmation link was sent to the new
    /// address instead (the usual case). Older servers leave it out.
    let emailChanged: Bool?
}
