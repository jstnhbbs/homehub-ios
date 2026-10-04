import { fromZonedTime } from "date-fns-tz";

export const CHORE_WEEKDAY_OPTIONS = [
  { value: "1", label: "Monday" },
  { value: "2", label: "Tuesday" },
  { value: "3", label: "Wednesday" },
  { value: "4", label: "Thursday" },
  { value: "5", label: "Friday" },
  { value: "6", label: "Saturday" },
  { value: "0", label: "Sunday" },
] as const;

export type ChoreWeekday = (typeof CHORE_WEEKDAY_OPTIONS)[number]["value"];

const ALL_DAYS = "0,1,2,3,4,5,6";

export function weeklyChoreDay(days: string): ChoreWeekday {
  const trimmed = days.trim();
  if (!trimmed.includes(",")) {
    return trimmed as ChoreWeekday;
  }
  return "1";
}

export function choreDaysForCadence(
  cadence: "daily" | "weekly",
  weekDay: string | undefined,
): string {
  if (cadence === "daily") return ALL_DAYS;
  return weekDay && /^[0-6]$/.test(weekDay) ? weekDay : "1";
}

export function weekdayLabel(day: string): string {
  return (
    CHORE_WEEKDAY_OPTIONS.find((option) => option.value === day)?.label ??
    "Monday"
  );
}

export function choreCadenceDetail(
  cadence: "daily" | "weekly",
  days: string,
): string {
  if (cadence === "daily") return "Every day";
  return `Once a week · ${weekdayLabel(weeklyChoreDay(days))}`;
}

export function localDayOfWeek(localDate: string, timezone: string): number {
  return fromZonedTime(`${localDate}T12:00:00`, timezone).getDay();
}

export function isChoreDueOnDate(
  cadence: "daily" | "weekly",
  days: string,
  localDate: string,
  timezone: string,
): boolean {
  if (cadence === "daily") return true;
  return weeklyChoreDay(days) === String(localDayOfWeek(localDate, timezone));
}

/**
 * A due date is a deadline, not a recurrence rule — it sits alongside cadence rather than
 * replacing it, so a daily chore can still carry a one-off "due Friday" label. Overdue only
 * once the date has passed and the current period is still unfinished.
 */
export function isChoreOverdue(
  dueDate: string | null,
  localDate: string,
  completed: boolean,
): boolean {
  if (!dueDate || completed) return false;
  return dueDate < localDate;
}
