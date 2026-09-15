import Foundation

struct NapLog: Codable, Identifiable, Sendable {
    let id: String
    let profileId: String
    let kind: String
    let localDate: String
    let startedAt: Date
    let endedAt: Date?
    let notes: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        profileId = try container.decode(String.self, forKey: .profileId)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "nap"
        localDate = try container.decode(String.self, forKey: .localDate)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, profileId, kind, localDate, startedAt, endedAt, notes
    }
}

struct NapsPayload: Codable, Sendable {
    let localDate: String
    let weekDates: [String]
    let childProfiles: [Profile]
    let naps: [NapLog]
    let weekLogs: [NapLog]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localDate = try container.decode(String.self, forKey: .localDate)
        weekDates = try container.decodeIfPresent([String].self, forKey: .weekDates) ?? []
        childProfiles = try container.decodeIfPresent([Profile].self, forKey: .childProfiles) ?? []
        naps = try container.decodeIfPresent([NapLog].self, forKey: .naps) ?? []
        weekLogs = try container.decodeIfPresent([NapLog].self, forKey: .weekLogs) ?? naps
    }

    private enum CodingKeys: String, CodingKey {
        case localDate, weekDates, childProfiles, naps, weekLogs
    }
}

struct NapActionRequest: Encodable, Sendable {
    let action: String
    var profileId: String?
    var napId: String?
    var startedAt: Date?
    var endedAt: Date?
    var fellAsleepAt: Date?
    var wokeUpAt: Date?
}

struct UpdateNapRequest: Encodable, Sendable {
    let startedAt: Date
    let endedAt: Date?
}
