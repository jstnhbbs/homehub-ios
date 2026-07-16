export const CALENDAR_SYNC_INTERVAL_OPTIONS = [
  { minutes: 0, label: "Manual only" },
  { minutes: 5, label: "Every 5 minutes" },
  { minutes: 15, label: "Every 15 minutes" },
  { minutes: 30, label: "Every 30 minutes" },
  { minutes: 60, label: "Every hour" },
] as const;

export const DEFAULT_CALENDAR_SYNC_INTERVAL_MINUTES = 15;

export function parseCalendarSyncIntervalMinutes(value: unknown) {
  const minutes = Number(value);
  if (
    CALENDAR_SYNC_INTERVAL_OPTIONS.some((option) => option.minutes === minutes)
  ) {
    return minutes;
  }
  return DEFAULT_CALENDAR_SYNC_INTERVAL_MINUTES;
}

export function calendarSyncIntervalMs(minutes: number) {
  return minutes * 60 * 1000;
}

export function calendarSyncCooldownMs(minutes: number) {
  if (minutes <= 0) return 0;
  const intervalMs = calendarSyncIntervalMs(minutes);
  return Math.max(intervalMs - 60_000, Math.floor(intervalMs * 0.8));
}
