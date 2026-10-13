import { addDays, format, getISOWeek, startOfWeek, type Day } from "date-fns";
import { formatInTimeZone, fromZonedTime } from "date-fns-tz";
import { DEFAULT_WEEK_STARTS_ON } from "@/lib/calendar/week-start";

/**
 * Whether this server can work in the named time zone. A household's zone is used on every request,
 * so one it doesn't know would break the household for good; it is checked when the household is made.
 */
export function isKnownTimeZone(timezone: string) {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone });
    return true;
  } catch {
    return false;
  }
}

export function localDateIn(timezone: string, date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

export function weekDates(
  from = new Date(),
  weekStartsOn: Day = DEFAULT_WEEK_STARTS_ON,
) {
  const start = startOfWeek(from, { weekStartsOn });
  return Array.from({ length: 7 }, (_, index) => addDays(start, index));
}

/**
 * The seven calendar dates ("yyyy-MM-dd") of the week that contains `localDate`, starting on `weekStartsOn`
 * (0 is Sunday). It only does arithmetic on the date itself, so it gives the same answer whatever time zone
 * the server runs in; going through an instant (noon in the household's zone) and then asking the server's
 * zone which week that falls in was wrong for zones far from UTC (Auckland, Fiji, Kiritimati).
 */
export function weekOfLocalDate(
  localDate: string,
  weekStartsOn: Day = DEFAULT_WEEK_STARTS_ON,
): string[] {
  const [year, month, day] = localDate.split("-").map(Number);
  const anchor = Date.UTC(year, month - 1, day);
  const weekday = new Date(anchor).getUTCDay();
  const back = (weekday - weekStartsOn + 7) % 7;
  return Array.from({ length: 7 }, (_, index) =>
    new Date(anchor + (index - back) * 86_400_000).toISOString().slice(0, 10),
  );
}

export function weekKey(date = new Date()) {
  return `${format(date, "RRRR")}-W${String(getISOWeek(date)).padStart(2, "0")}`;
}

export function formatLocalDate(
  localDate: string,
  timezone: string,
  pattern: string,
) {
  return formatInTimeZone(
    fromZonedTime(`${localDate}T12:00:00`, timezone),
    timezone,
    pattern,
  );
}
