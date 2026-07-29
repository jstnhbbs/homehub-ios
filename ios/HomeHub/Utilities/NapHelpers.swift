import Foundation

struct ChildDayNapStats: Sendable {
    let localDate: String
    let napCount: Int
    let nightCount: Int
    let totalMinutes: Int
}

struct ChildWeekNapStats: Sendable {
    let profileId: String
    let days: [ChildDayNapStats]
    let totalNaps: Int
    let totalNights: Int
    let totalMinutes: Int
    let avgNapsPerDay: Double
    let avgMinutesPerDay: Double
    let elapsedDays: Int
}

struct ChildDashboardSleepStatus: Sendable {
    enum State: Sendable {
        case napping
        case inBed
        case awake
        case empty
    }

    let state: State
    let activeLogId: String?
    let activeKind: String?
    let startedAt: Date?
    let durationMinutes: Int
    let todayNapCount: Int
    let todayNightCount: Int
    let todayTotalMinutes: Int
    let hasCompletedToday: Bool
}

enum NapHelpers {
    static func durationMinutes(startedAt: Date, endedAt: Date?, now: Date = .now) -> Int {
        let end = endedAt ?? now
        return max(0, Int(end.timeIntervalSince(startedAt) / 60))
    }

    static func formatDuration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func childProfiles(from profiles: [Profile]) -> [Profile] {
        profiles.filter { $0.profileType == .child }
    }

    static func activeNap(for profileId: String, in naps: [NapLog]) -> NapLog? {
        naps.first { $0.profileId == profileId && $0.kind == "nap" && $0.endedAt == nil }
    }

    static func activeNight(for profileId: String, in logs: [NapLog]) -> NapLog? {
        logs.first { $0.profileId == profileId && $0.kind == "night" && $0.endedAt == nil }
    }

    static func activeSleep(for profileId: String, in logs: [NapLog]) -> NapLog? {
        logs.first { $0.profileId == profileId && $0.endedAt == nil }
    }

    static func getChildDashboardSleepStatus(
        logs: [NapLog],
        profileId: String,
        localDate: String,
        timezone: TimeZone,
        now: Date = .now
    ) -> ChildDashboardSleepStatus {
        let todayLogs = logsForDate(
            profileId: profileId,
            in: logs,
            localDate: localDate,
            timezone: timezone,
            now: now
        )
        let active = logs.first { $0.profileId == profileId && $0.endedAt == nil }

        if let active {
            let completedToday = todayLogs.filter { $0.endedAt != nil }
            let stats = completedToday.reduce(into: (napCount: 0, nightCount: 0, totalMinutes: 0)) { partial, log in
                if log.kind == "night" {
                    partial.nightCount += 1
                } else {
                    partial.napCount += 1
                }
                partial.totalMinutes += durationMinutes(startedAt: log.startedAt, endedAt: log.endedAt, now: now)
            }
            return ChildDashboardSleepStatus(
                state: active.kind == "night" ? .inBed : .napping,
                activeLogId: active.id,
                activeKind: active.kind,
                startedAt: active.startedAt,
                durationMinutes: durationMinutes(startedAt: active.startedAt, endedAt: nil, now: now),
                todayNapCount: stats.napCount,
                todayNightCount: stats.nightCount,
                todayTotalMinutes: stats.totalMinutes,
                hasCompletedToday: !completedToday.isEmpty
            )
        }

        if todayLogs.isEmpty {
            return ChildDashboardSleepStatus(
                state: .empty,
                activeLogId: nil,
                activeKind: nil,
                startedAt: nil,
                durationMinutes: 0,
                todayNapCount: 0,
                todayNightCount: 0,
                todayTotalMinutes: 0,
                hasCompletedToday: false
            )
        }

        let lastEnded = todayLogs.compactMap(\.endedAt).max()
        let awakeMinutes = lastEnded.map { max(0, Int(now.timeIntervalSince($0) / 60)) } ?? 0
        let napCount = todayLogs.filter { $0.kind == "nap" }.count
        let nightCount = todayLogs.filter { $0.kind == "night" }.count
        let totalMinutes = todayLogs.reduce(0) { partial, log in
            partial + durationMinutes(startedAt: log.startedAt, endedAt: log.endedAt, now: now)
        }

        return ChildDashboardSleepStatus(
            state: .awake,
            activeLogId: nil,
            activeKind: nil,
            startedAt: nil,
            durationMinutes: awakeMinutes,
            todayNapCount: napCount,
            todayNightCount: nightCount,
            todayTotalMinutes: totalMinutes,
            hasCompletedToday: true
        )
    }

    static func dashboardSleepSecondary(for status: ChildDashboardSleepStatus) -> String? {
        switch status.state {
        case .inBed:
            return "Night in progress"
        case .napping:
            if status.hasCompletedToday {
                return daySummary(
                    napCount: status.todayNapCount,
                    nightCount: status.todayNightCount,
                    totalMinutes: status.todayTotalMinutes
                )
            }
            return "Nap in progress"
        case .awake:
            return daySummary(
                napCount: status.todayNapCount,
                nightCount: status.todayNightCount,
                totalMinutes: status.todayTotalMinutes
            )
        case .empty:
            return nil
        }
    }

    static func sleepOverlapsLocalDate(_ log: NapLog, localDate: String, timezone: TimeZone, now: Date = .now) -> Bool {
        guard let dayStart = DateHelpers.dateFromLocalDate(localDate, timezone: timezone),
              let dayEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: dayStart)?.addingTimeInterval(-0.001) else {
            return log.localDate == localDate
        }
        let sleepEnd = log.endedAt ?? now
        return log.startedAt <= dayEnd && sleepEnd >= dayStart
    }

    static func logsForDate(
        profileId: String?,
        in logs: [NapLog],
        localDate: String,
        timezone: TimeZone,
        now: Date = .now
    ) -> [NapLog] {
        logs.filter { log in
            (profileId == nil || log.profileId == profileId) &&
            sleepOverlapsLocalDate(log, localDate: localDate, timezone: timezone, now: now)
        }
    }

    static func todayNaps(for profileId: String, in naps: [NapLog], localDate: String) -> [NapLog] {
        naps.filter { $0.profileId == profileId && $0.localDate == localDate }
    }

    static func todaySummary(
        for profileId: String,
        in naps: [NapLog],
        localDate: String,
        now: Date = .now,
        isActive: Bool = false
    ) -> String {
        let todayNaps = Self.todayNaps(for: profileId, in: naps, localDate: localDate)
        if todayNaps.isEmpty { return "No naps logged today" }

        let count = todayNaps.count
        let totalMinutes = todayNaps.reduce(0) { partial, nap in
            partial + Self.durationMinutes(startedAt: nap.startedAt, endedAt: nap.endedAt, now: now)
        }

        var parts = [
            "\(count) nap\(count == 1 ? "" : "s")",
            "\(Self.formatDuration(minutes: totalMinutes)) total",
        ]

        if !isActive,
           let lastEnded = todayNaps.compactMap(\.endedAt).max() {
            let awakeMinutes = max(0, Int(now.timeIntervalSince(lastEnded) / 60))
            parts.append("Awake \(Self.formatDuration(minutes: awakeMinutes))")
        }

        return parts.joined(separator: " · ")
    }

    static func daySummary(napCount: Int, nightCount: Int, totalMinutes: Int) -> String {
        if napCount == 0 && nightCount == 0 { return "No sleep logged" }
        var parts: [String] = []
        if napCount > 0 { parts.append("\(napCount) nap\(napCount == 1 ? "" : "s")") }
        if nightCount > 0 { parts.append("\(nightCount) night\(nightCount == 1 ? "" : "s")") }
        parts.append("\(formatDuration(minutes: totalMinutes)) total")
        return parts.joined(separator: " · ")
    }

    static func formatAverageNapCount(_ value: Double) -> String {
        if value.rounded(.towardZero) == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    static func childWeekStats(
        profileId: String,
        naps: [NapLog],
        weekDates: [String],
        todayLocalDate: String,
        timezone: TimeZone,
        now: Date = .now
    ) -> ChildWeekNapStats {
        let days = weekDates.map { localDate in
            let dayLogs = logsForDate(profileId: profileId, in: naps, localDate: localDate, timezone: timezone, now: now)
            let napCount = dayLogs.filter { $0.kind == "nap" }.count
            let nightCount = dayLogs.filter { $0.kind == "night" }.count
            let totalMinutes = dayLogs.reduce(0) { partial, nap in
                partial + durationMinutes(startedAt: nap.startedAt, endedAt: nap.endedAt, now: now)
            }
            return ChildDayNapStats(localDate: localDate, napCount: napCount, totalMinutes: totalMinutes, nightCount: nightCount)
        }
        let elapsedDays = weekDates.filter { $0 <= todayLocalDate }.count
        let totalNaps = days.reduce(0) { $0 + $1.napCount }
        let totalNights = days.reduce(0) { $0 + $1.nightCount }
        let totalMinutes = days.reduce(0) { $0 + $1.totalMinutes }
        let avgDivisor = max(elapsedDays, 1)
        let totalSessions = totalNaps + totalNights

        return ChildWeekNapStats(
            profileId: profileId,
            days: days,
            totalNaps: totalNaps,
            totalNights: totalNights,
            totalMinutes: totalMinutes,
            avgNapsPerDay: Double(totalSessions) / Double(avgDivisor),
            avgMinutesPerDay: Double(totalMinutes) / Double(avgDivisor),
            elapsedDays: elapsedDays
        )
    }
}

struct NapTimelineBar: Identifiable, Sendable {
    var id: String { napId }
    let napId: String
    let leftPercent: Double
    let widthPercent: Double
    let durationLabel: String
}

struct AwakeGap: Identifiable, Sendable {
    var id: String { "\(leftPercent)-\(minutes)" }
    let leftPercent: Double
    let widthPercent: Double
    let minutes: Int
    let label: String
}

struct HeatmapBlock: Sendable {
    let startHour: Int
    let endHour: Int
    let label: String
}

enum NapTimelineHelpers {
    static let startHour = 5
    static let endHour = 23
    static let hourLabels = ["5a", "8a", "11a", "2p", "5p", "8p", "11p"]
    static let heatmapBlocks: [HeatmapBlock] = [
        HeatmapBlock(startHour: 5, endHour: 8, label: "5–8a"),
        HeatmapBlock(startHour: 8, endHour: 11, label: "8–11a"),
        HeatmapBlock(startHour: 11, endHour: 14, label: "11–2p"),
        HeatmapBlock(startHour: 14, endHour: 17, label: "2–5p"),
        HeatmapBlock(startHour: 17, endHour: 20, label: "5–8p"),
        HeatmapBlock(startHour: 20, endHour: 23, label: "8–11p"),
    ]

    static func minutesOnLocalDate(_ date: Date, localDate: String, timezone: TimeZone) -> Int? {
        guard DateHelpers.localDateIn(timezone: timezone, date: date) == localDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func timelinePercents(startMinutes: Int, endMinutes: Int) -> (left: Double, width: Double) {
        let rangeStart = startHour * 60
        let rangeEnd = endHour * 60
        let rangeDuration = rangeEnd - rangeStart
        let clampedStart = max(rangeStart, min(rangeEnd, startMinutes))
        let clampedEnd = max(clampedStart, min(rangeEnd, endMinutes))
        let left = Double(clampedStart - rangeStart) / Double(rangeDuration) * 100
        let width = max(Double(clampedEnd - clampedStart) / Double(rangeDuration) * 100, 1.5)
        return (left, width)
    }

    static func dayTimelineBars(naps: [NapLog], localDate: String, timezone: TimeZone, now: Date = .now) -> [NapTimelineBar] {
        naps.filter { NapHelpers.sleepOverlapsLocalDate($0, localDate: localDate, timezone: timezone, now: now) }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { nap in
            guard let dayStart = DateHelpers.dateFromLocalDate(localDate, timezone: timezone) else { return nil }
            let dayEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: dayStart)?.addingTimeInterval(-0.001) ?? dayStart
            let sleepEnd = nap.endedAt ?? now
            let overlapStart = max(nap.startedAt, dayStart)
            let overlapEnd = min(sleepEnd, dayEnd)
            if overlapStart >= overlapEnd { return nil }
            guard
                let startMinutes = minutesOnLocalDate(overlapStart, localDate: localDate, timezone: timezone),
                var endMinutes = minutesOnLocalDate(overlapEnd, localDate: localDate, timezone: timezone)
            else { return nil }
            if endMinutes <= startMinutes { endMinutes = endHour * 60 }
            if endMinutes <= startMinutes { return nil }
            let percents = timelinePercents(startMinutes: startMinutes, endMinutes: endMinutes)
            let duration = NapHelpers.durationMinutes(startedAt: nap.startedAt, endedAt: nap.endedAt, now: now)
            let label = nap.kind == "night" ? "Night · \(NapHelpers.formatDuration(minutes: duration))" : NapHelpers.formatDuration(minutes: duration)
            return NapTimelineBar(
                napId: nap.id,
                leftPercent: percents.left,
                widthPercent: percents.width,
                durationLabel: label
            )
        }
    }

    static func awakeGaps(naps: [NapLog], localDate: String, timezone: TimeZone) -> [AwakeGap] {
        let sorted = naps.filter { NapHelpers.sleepOverlapsLocalDate($0, localDate: localDate, timezone: timezone) && $0.endedAt != nil }.sorted { $0.startedAt < $1.startedAt }
        var gaps: [AwakeGap] = []
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            guard let previousEnd = previous.endedAt else { continue }
            let gapMinutes = max(0, Int(current.startedAt.timeIntervalSince(previousEnd) / 60))
            if gapMinutes < 5 { continue }
            guard
                let gapStart = minutesOnLocalDate(previousEnd, localDate: localDate, timezone: timezone),
                let gapEnd = minutesOnLocalDate(current.startedAt, localDate: localDate, timezone: timezone)
            else { continue }
            let percents = timelinePercents(startMinutes: gapStart, endMinutes: gapEnd)
            gaps.append(AwakeGap(
                leftPercent: percents.left,
                widthPercent: percents.width,
                minutes: gapMinutes,
                label: "Awake \(NapHelpers.formatDuration(minutes: gapMinutes))"
            ))
        }
        return gaps
    }

    static func overlapsHeatmapBlock(nap: NapLog, localDate: String, timezone: TimeZone, block: HeatmapBlock, now: Date = .now) -> Bool {
        guard NapHelpers.sleepOverlapsLocalDate(nap, localDate: localDate, timezone: timezone, now: now),
              let dayStart = DateHelpers.dateFromLocalDate(localDate, timezone: timezone) else { return false }
        let dayEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: dayStart)?.addingTimeInterval(-0.001) ?? dayStart
        let sleepEnd = nap.endedAt ?? now
        let overlapStart = max(nap.startedAt, dayStart)
        let overlapEnd = min(sleepEnd, dayEnd)
        if overlapStart >= overlapEnd { return false }
        guard
            let startMinutes = minutesOnLocalDate(overlapStart, localDate: localDate, timezone: timezone),
            let endMinutes = minutesOnLocalDate(overlapEnd, localDate: localDate, timezone: timezone)
        else { return false }
        return startMinutes < block.endHour * 60 && endMinutes > block.startHour * 60
    }
}
