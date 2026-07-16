import { formatInTimeZone } from "date-fns-tz";

type CalendarConnection = {
  lastSyncedAt: Date | null;
};

export function calendarSyncStatus(
  connections: CalendarConnection[],
  timezone: string,
) {
  if (!connections.length) {
    return {
      connected: false,
      updatedLabel: undefined as string | undefined,
      lastSyncedAt: undefined as string | undefined,
    };
  }
  const latest = connections.reduce((current, connection) => {
    if (!connection.lastSyncedAt) return current;
    if (!current) return connection.lastSyncedAt;
    return connection.lastSyncedAt > current
      ? connection.lastSyncedAt
      : current;
  }, null as Date | null);
  return {
    connected: true,
    updatedLabel: latest
      ? `Updated ${formatInTimeZone(latest, timezone, "h:mm a")}`
      : undefined,
    lastSyncedAt: latest?.toISOString(),
  };
}
