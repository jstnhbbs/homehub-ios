import SwiftUI

/// One child's sleep state at a glance: asleep or awake, for how long, and the one action that makes
/// sense next. Replaces the separate "Nap timer" and "Bedtime" cards, which listed every child twice.
struct SleepStatusCard: View {
    let profile: Profile
    let logs: [NapLog]
    let localDate: String
    let timezone: TimeZone
    let now: Date
    let startNap: () async -> Void
    let startBedtime: () async -> Void
    let endSleep: (NapLog) async -> Void

    private var active: NapLog? { NapHelpers.activeSleep(for: profile.id, in: logs) }

    /// When they last woke up, counting a night that ended this morning.
    private var lastWake: Date? {
        logs.filter { $0.profileId == profile.id }.compactMap(\.endedAt).max()
    }

    private var todayLogs: [NapLog] {
        NapHelpers.logsForDate(profileId: profile.id, in: logs, localDate: localDate, timezone: timezone, now: now)
    }

    private var todaySummary: String {
        let logs = todayLogs
        return NapHelpers.daySummary(
            napCount: logs.filter { $0.kind == "nap" }.count,
            nightCount: logs.filter { $0.kind == "night" }.count,
            totalMinutes: logs.reduce(0) {
                $0 + NapHelpers.overlapMinutes(startedAt: $1.startedAt, endedAt: $1.endedAt, localDate: localDate, timezone: timezone, now: now)
            }
        )
    }

    private var tint: Color { HubTheme.profileColor(profile.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProfileAvatarView(name: profile.name, avatar: profile.avatar, color: profile.color, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                    statePill
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(subheadline)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(HubTheme.muted)
            }

            Text(todaySummary)
                .font(.caption.weight(.bold))
                .foregroundStyle(HubTheme.muted)

            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(active == nil ? HubTheme.tile : tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(active == nil ? HubTheme.line : tint.opacity(0.55), lineWidth: active == nil ? 1 : 2)
        )
        .accessibilityElement(children: .contain)
    }

    private var statePill: some View {
        let (icon, label): (String, String) = {
            guard let active else { return ("sun.max.fill", "Awake") }
            return active.kind == "night" ? ("bed.double.fill", "In bed") : ("moon.zzz.fill", "Napping")
        }()
        return Label(label, systemImage: icon)
            .font(.caption.weight(.heavy))
            .foregroundStyle(active == nil ? HubTheme.muted : tint)
    }

    private var headline: String {
        if let active {
            return durationText(NapHelpers.durationMinutes(startedAt: active.startedAt, endedAt: nil, now: now))
        }
        guard let lastWake else { return "No sleep yet" }
        return durationText(max(0, Int(now.timeIntervalSince(lastWake) / 60)))
    }

    private func durationText(_ minutes: Int) -> String {
        minutes < 1 ? "<1m" : NapHelpers.formatDuration(minutes: minutes)
    }

    private var subheadline: String {
        if let active {
            let since = DateHelpers.timeString(active.startedAt, timezone: timezone)
            return active.kind == "night" ? "in bed since \(since)" : "asleep since \(since)"
        }
        guard let lastWake else { return "Start a nap or bedtime below" }
        return "awake since \(DateHelpers.timeString(lastWake, timezone: timezone))"
    }

    @ViewBuilder
    private var actions: some View {
        if let active {
            Button {
                Task { await endSleep(active) }
            } label: {
                Label(active.kind == "night" ? "Log wake up" : "End nap", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HubButtonStyle(emphasis: .primary))
        } else {
            HStack(spacing: 10) {
                Button {
                    Task { await startNap() }
                } label: {
                    Label("Start Nap", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .primary))

                Button {
                    Task { await startBedtime() }
                } label: {
                    Label("Bedtime", systemImage: "bed.double.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HubButtonStyle(emphasis: .secondary))
            }
        }
    }
}
