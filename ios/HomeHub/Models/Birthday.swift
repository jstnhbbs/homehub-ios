import Foundation

enum BirthdaySource: String, Codable, Sendable {
    case profile
    case family
}

struct BirthdayItem: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var source: BirthdaySource
    var profileId: String?
    var name: String
    var birthDate: String
    var color: String
    var avatar: String?
    var notes: String?
    /// Reserved for a later gift-ideas UI. Extra people already persist this field.
    var giftIdeas: String?
    var notifyDaysBefore: Int
    var nextDate: String
    var daysUntil: Int
    var upcomingAge: Int
}

struct BirthdaysPayload: Codable, Sendable {
    var items: [BirthdayItem]
}

struct BirthdayWriteInput: Codable, Sendable {
    var name: String
    var birthDate: String
    var profileId: String?
    var notes: String?
    var giftIdeas: String?
    var notifyDaysBefore: Int?
}

struct BirthdayCreateResponse: Codable, Sendable {
    var item: BirthdayItem?
    var items: [BirthdayItem]
}

struct BirthdayMonthGroup: Identifiable, Sendable {
    let id: Int
    let month: Int
    let title: String
    let items: [BirthdayItem]
}
