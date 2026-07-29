import type { SleepKind } from "@/db/schema";
import { sleepLogsForDate } from "@/lib/naps/overlap";

export function napDurationMinutes(
  startedAt: Date,
  endedAt: Date | null,
  now: Date = new Date(),
): number {
  const end = endedAt ?? now;
  return Math.max(0, Math.floor((end.getTime() - startedAt.getTime()) / 60_000));
}

export function formatSleepDuration(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder ? `${hours}h ${remainder}m` : `${hours}h`;
}

/** @deprecated Use formatSleepDuration */
export const formatNapDuration = formatSleepDuration;

export function totalSleepMinutes(
  logs: Array<{ startedAt: Date; endedAt: Date | null }>,
  now: Date = new Date(),
): number {
  return logs.reduce(
    (total, log) => total + napDurationMinutes(log.startedAt, log.endedAt, now),
    0,
  );
}

/** @deprecated Use totalSleepMinutes */
export const totalNapMinutes = totalSleepMinutes;

export type ChildDaySleepStats = {
  localDate: string;
  napCount: number;
  nightCount: number;
  totalMinutes: number;
};

export type ChildWeekSleepStats = {
  profileId: string;
  days: ChildDaySleepStats[];
  totalNaps: number;
  totalNights: number;
  totalMinutes: number;
  avgSessionsPerDay: number;
  avgMinutesPerDay: number;
  elapsedDays: number;
};

/** @deprecated Use ChildDaySleepStats */
export type ChildDayNapStats = ChildDaySleepStats & { napCount: number };

/** @deprecated Use ChildWeekSleepStats */
export type ChildWeekNapStats = ChildWeekSleepStats & {
  totalNaps: number;
  avgNapsPerDay: number;
};

export function childNapsForDate<
  T extends {
    kind?: SleepKind;
    profileId: string;
    localDate: string;
    startedAt: Date;
    endedAt: Date | null;
  },
>(
  logs: T[],
  profileId: string,
  localDate: string,
  timezone: string,
  now: Date = new Date(),
) {
  return sleepLogsForDate(logs, profileId, localDate, timezone, now);
}

export function daySleepStats<
  T extends { kind?: SleepKind; startedAt: Date; endedAt: Date | null },
>(logs: T[], now: Date = new Date()) {
  const naps = logs.filter((log) => (log.kind ?? "nap") === "nap");
  const nights = logs.filter((log) => log.kind === "night");
  return {
    napCount: naps.length,
    nightCount: nights.length,
    totalMinutes: totalSleepMinutes(logs, now),
  };
}

export function childDaySleepStats<
  T extends {
    kind?: SleepKind;
    profileId: string;
    localDate: string;
    startedAt: Date;
    endedAt: Date | null;
  },
>(
  logs: T[],
  profileId: string,
  localDate: string,
  timezone: string,
  now: Date = new Date(),
): ChildDaySleepStats {
  const dayLogs = childNapsForDate(logs, profileId, localDate, timezone, now);
  return {
    localDate,
    ...daySleepStats(dayLogs, now),
  };
}

export function childWeekSleepStats<
  T extends {
    kind?: SleepKind;
    profileId: string;
    localDate: string;
    startedAt: Date;
    endedAt: Date | null;
  },
>(
  logs: T[],
  profileId: string,
  weekDates: string[],
  todayLocalDate: string,
  timezone: string,
  now: Date = new Date(),
): ChildWeekSleepStats {
  const days = weekDates.map((localDate) =>
    childDaySleepStats(logs, profileId, localDate, timezone, now),
  );
  const elapsedDays = weekDates.filter((date) => date <= todayLocalDate).length;
  const totalNaps = days.reduce((sum, day) => sum + day.napCount, 0);
  const totalNights = days.reduce((sum, day) => sum + day.nightCount, 0);
  const totalMinutes = days.reduce((sum, day) => sum + day.totalMinutes, 0);
  const totalSessions = totalNaps + totalNights;

  return {
    profileId,
    days,
    totalNaps,
    totalNights,
    totalMinutes,
    avgSessionsPerDay: elapsedDays ? totalSessions / elapsedDays : 0,
    avgMinutesPerDay: elapsedDays ? totalMinutes / elapsedDays : 0,
    elapsedDays,
  };
}

/** @deprecated Use childWeekSleepStats */
export function childWeekNapStats<
  T extends {
    kind?: SleepKind;
    profileId: string;
    localDate: string;
    startedAt: Date;
    endedAt: Date | null;
  },
>(
  logs: T[],
  profileId: string,
  weekDates: string[],
  todayLocalDate: string,
  now: Date = new Date(),
) {
  return childWeekSleepStats(
    logs,
    profileId,
    weekDates,
    todayLocalDate,
    "UTC",
    now,
  );
}

export function formatChildDaySummary(
  napCount: number,
  nightCount: number,
  totalMinutes: number,
) {
  if (napCount === 0 && nightCount === 0) return "No sleep logged";
  const parts: string[] = [];
  if (napCount) parts.push(`${napCount} nap${napCount === 1 ? "" : "s"}`);
  if (nightCount) parts.push(`${nightCount} night${nightCount === 1 ? "" : "s"}`);
  parts.push(`${formatSleepDuration(totalMinutes)} total`);
  return parts.join(" · ");
}

export function formatAverageSessionCount(value: number) {
  if (Number.isInteger(value)) return String(value);
  return value.toFixed(1);
}

/** @deprecated Use formatAverageSessionCount */
export const formatAverageNapCount = formatAverageSessionCount;

export function sleepKindLabel(kind: SleepKind = "nap") {
  return kind === "night" ? "Night sleep" : "Nap";
}

export function formatChildTodaySleepSummary(
  logs: Array<{
    kind?: SleepKind;
    startedAt: Date;
    endedAt: Date | null;
  }>,
  now: Date = new Date(),
  options?: { isActive?: boolean },
) {
  if (logs.length === 0) return "No sleep logged today";

  const stats = daySleepStats(logs, now);
  const parts = [
    formatChildDaySummary(stats.napCount, stats.nightCount, stats.totalMinutes),
  ];

  if (!options?.isActive) {
    const lastEnded = logs
      .map((log) => log.endedAt)
      .filter((value): value is Date => value != null)
      .sort((a, b) => b.getTime() - a.getTime())[0];

    if (lastEnded) {
      const awakeMinutes = Math.max(
        0,
        Math.floor((now.getTime() - lastEnded.getTime()) / 60_000),
      );
      parts.push(`Awake ${formatSleepDuration(awakeMinutes)}`);
    }
  }

  return parts.join(" · ");
}

export type ChildDashboardSleepStatus = {
  state: "napping" | "in_bed" | "awake" | "empty";
  activeLogId: string | null;
  activeKind: SleepKind | null;
  startedAt: Date | null;
  durationMinutes: number;
  todayStats: ReturnType<typeof daySleepStats> | null;
};

export function getChildDashboardSleepStatus<
  T extends {
    id: string;
    kind?: SleepKind;
    profileId: string;
    localDate: string;
    startedAt: Date;
    endedAt: Date | null;
  },
>(
  logs: T[],
  profileId: string,
  localDate: string,
  timezone: string,
  now: Date = new Date(),
): ChildDashboardSleepStatus {
  const todayLogs = childNapsForDate(logs, profileId, localDate, timezone, now);
  const active = logs.find(
    (log) => log.profileId === profileId && log.endedAt == null,
  );

  if (active) {
    const completedToday = todayLogs.filter((log) => log.endedAt != null);
    return {
      state: active.kind === "night" ? "in_bed" : "napping",
      activeLogId: active.id,
      activeKind: active.kind ?? "nap",
      startedAt: active.startedAt,
      durationMinutes: napDurationMinutes(active.startedAt, null, now),
      todayStats: completedToday.length
        ? daySleepStats(completedToday, now)
        : null,
    };
  }

  if (todayLogs.length === 0) {
    return {
      state: "empty",
      activeLogId: null,
      activeKind: null,
      startedAt: null,
      durationMinutes: 0,
      todayStats: null,
    };
  }

  const lastEnded = todayLogs
    .map((log) => log.endedAt)
    .filter((value): value is Date => value != null)
    .sort((a, b) => b.getTime() - a.getTime())[0];

  return {
    state: "awake",
    activeLogId: null,
    activeKind: null,
    startedAt: null,
    durationMinutes: lastEnded
      ? Math.max(
          0,
          Math.floor((now.getTime() - lastEnded.getTime()) / 60_000),
        )
      : 0,
    todayStats: daySleepStats(todayLogs, now),
  };
}

export function formatDashboardSleepSecondary(
  status: ChildDashboardSleepStatus,
): string | null {
  if (status.state === "in_bed") return "Night in progress";
  if (status.state === "napping") {
    if (status.todayStats) {
      return formatChildDaySummary(
        status.todayStats.napCount,
        status.todayStats.nightCount,
        status.todayStats.totalMinutes,
      );
    }
    return "Nap in progress";
  }
  if (status.state === "awake" && status.todayStats) {
    return formatChildDaySummary(
      status.todayStats.napCount,
      status.todayStats.nightCount,
      status.todayStats.totalMinutes,
    );
  }
  return null;
}

/** @deprecated Use formatChildTodaySleepSummary */
export function formatChildTodayNapSummary(
  naps: Array<{ localDate: string; startedAt: Date; endedAt: Date | null }>,
  _localDate: string,
  now: Date = new Date(),
  options?: { isActive?: boolean },
) {
  return formatChildTodaySleepSummary(
    naps.map((nap) => ({ ...nap, kind: "nap" as const })),
    now,
    options,
  );
}
