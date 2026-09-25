import Foundation

enum BirthdaySource: String, Codable, Sendable {
    case profile
    case family
}

/// Birthdays and anniversaries are counted the same way; only the wording differs.
enum CelebrationKind: String, Codable, Sendable, CaseIterable, Hashable {
    case birthday
    case anniversary
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
    /// The age they turn, or for an anniversary the number of years it marks.
    var upcomingAge: Int
    /// Older servers do not send this; those entries are birthdays.
    var kind: CelebrationKind = .birthday
}

extension BirthdayItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            source: try container.decode(BirthdaySource.self, forKey: .source),
            profileId: try container.decodeIfPresent(String.self, forKey: .profileId),
            name: try container.decode(String.self, forKey: .name),
            birthDate: try container.decode(String.self, forKey: .birthDate),
            color: try container.decode(String.self, forKey: .color),
            avatar: try container.decodeIfPresent(String.self, forKey: .avatar),
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            giftIdeas: try container.decodeIfPresent(String.self, forKey: .giftIdeas),
            notifyDaysBefore: try container.decode(Int.self, forKey: .notifyDaysBefore),
            nextDate: try container.decode(String.self, forKey: .nextDate),
            daysUntil: try container.decode(Int.self, forKey: .daysUntil),
            upcomingAge: try container.decode(Int.self, forKey: .upcomingAge),
            kind: try container.decodeIfPresent(CelebrationKind.self, forKey: .kind) ?? .birthday
        )
    }
}

struct BirthdaysPayload: Codable, Sendable {
    var items: [BirthdayItem]
}

struct BirthdayWriteInput: Codable, Sendable {
    var name: String
    var birthDate: String
    var kind: CelebrationKind?
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
