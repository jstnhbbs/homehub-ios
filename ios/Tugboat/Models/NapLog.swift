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

/// What a sleep write sends back: the entry it created or changed (nil from an older server).
struct NapWriteResponse: Decodable, Sendable {
    let nap: NapLog?
}

struct NapsPayload: Codable, Sendable {
    let localDate: String
    let weekDates: [String]
    let childProfiles: [Profile]
    var naps: [NapLog]
    var weekLogs: [NapLog]

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

extension NapsPayload {
    /// Shows an entry the server just created or changed without refetching the page. A reload in
    /// the background follows to reconcile anything this can't know about.
    mutating func apply(_ log: NapLog) {
        func upserted(_ logs: [NapLog], addingIfMissing: Bool) -> [NapLog] {
            var result = logs
            if let index = result.firstIndex(where: { $0.id == log.id }) {
                result[index] = log
            } else if addingIfMissing {
                result.append(log)
            }
            return result.sorted { $0.startedAt < $1.startedAt }
        }
        weekLogs = upserted(weekLogs, addingIfMissing: true)
        // `naps` holds today's naps and anything still running.
        naps = upserted(naps, addingIfMissing: log.kind == "nap" || log.endedAt == nil)
    }

    mutating func remove(id: String) {
        weekLogs.removeAll { $0.id == id }
        naps.removeAll { $0.id == id }
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
