import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var email: String
    var emailVerified: Bool
    var image: String?
    var createdAt: Date?
    var updatedAt: Date?
}

struct Session: Codable, Sendable {
    let user: User
    let session: SessionToken
}

struct SessionToken: Codable, Sendable {
    let id: String
    let token: String
    let expiresAt: Date
    let userId: String
}

struct AuthResponse: Codable, Sendable {
    let user: User?
    let session: SessionToken?
    let token: String?
}
