import { fromZonedTime } from "date-fns-tz";
import type { SleepKind } from "@/db/schema";

export type SleepLogLike = {
  kind?: SleepKind;
  localDate: string;
  startedAt: Date;
  endedAt: Date | null;
};

export function localDayBounds(localDate: string, timezone: string) {
  return {
    start: fromZonedTime(`${localDate}T00:00:00`, timezone),
    end: fromZonedTime(`${localDate}T23:59:59.999`, timezone),
  };
}

export function sleepOverlapsLocalDate(
  log: SleepLogLike,
  localDate: string,
  timezone: string,
  now: Date = new Date(),
) {
  const { start, end } = localDayBounds(localDate, timezone);
  const sleepEnd = log.endedAt ?? now;
  return log.startedAt <= end && sleepEnd >= start;
}

export function sleepLogsForDate<
  T extends SleepLogLike & { profileId: string },
>(logs: T[], profileId: string, localDate: string, timezone: string, now?: Date) {
  return logs.filter(
    (log) =>
      log.profileId === profileId &&
      sleepOverlapsLocalDate(log, localDate, timezone, now),
  );
}

export function sleepLogsOnDate<
  T extends SleepLogLike,
>(logs: T[], localDate: string, timezone: string, now?: Date) {
  return logs.filter((log) => sleepOverlapsLocalDate(log, localDate, timezone, now));
}

export function overlapMinutesOnLocalDate(
  log: SleepLogLike,
  localDate: string,
  timezone: string,
  now: Date = new Date(),
) {
  if (!sleepOverlapsLocalDate(log, localDate, timezone, now)) return 0;
  const { start, end } = localDayBounds(localDate, timezone);
  const sleepEnd = log.endedAt ?? now;
  const overlapStart = Math.max(log.startedAt.getTime(), start.getTime());
  const overlapEnd = Math.min(sleepEnd.getTime(), end.getTime() + 1);
  return Math.max(0, Math.floor((overlapEnd - overlapStart) / 60_000));
}
