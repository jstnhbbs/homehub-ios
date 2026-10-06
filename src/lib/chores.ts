import { localDateIn, weekKey } from "@/lib/dates";

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
export type ChoreRepeatUnit = "none" | "day" | "week" | "month" | "year";

const ALL_DAYS = "0,1,2,3,4,5,6";
const MAX_INTERVAL = 99;

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

export function weeklyChoreDay(days: string): ChoreWeekday {
  const trimmed = days.trim();
  if (/^[0-6]$/.test(trimmed)) return trimmed as ChoreWeekday;
  return "1";
}

export function weekdayLabel(day: string): string {
  return (
    CHORE_WEEKDAY_OPTIONS.find((option) => option.value === day)?.label ??
    "Monday"
  );
}

// Dates are handled as day numbers (days since 1970-01-01, UTC) so that daylight saving and the
// server's own time zone can never move a calendar date.

function isRealDate(value: string): boolean {
  if (!DATE_PATTERN.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

function dayNumber(localDate: string): number {
  const [year, month, day] = localDate.split("-").map(Number);
  return Math.round(Date.UTC(year, month - 1, day) / 86_400_000);
}

function dateFromDayNumber(day: number): string {
  return new Date(day * 86_400_000).toISOString().slice(0, 10);
}

function weekdayOf(day: number): number {
  return new Date(day * 86_400_000).getUTCDay();
}

/** The Monday of the week a day falls in. */
function mondayOf(day: number): number {
  return day - ((weekdayOf(day) + 6) % 7);
}

function parts(day: number) {
  const date = new Date(day * 86_400_000);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
  };
}

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}

/** Where a chore falls in the calendar. What is stored, after the rules have been applied. */
export type ChoreSchedule = {
  repeatUnit: ChoreRepeatUnit;
  repeatInterval: number;
  /** Weekdays (0 = Sunday) as "1,3,5": the one weekday of a weekly chore, or the days a daily one runs. */
  days: string;
  dueDate: string | null;
  dueTime: string | null;
};

export type ChoreScheduleInput = {
  cadence?: "daily" | "weekly";
  repeatUnit?: ChoreRepeatUnit;
  repeatInterval?: number;
  /** The weekday of a weekly chore. */
  weekDay?: string;
  /** Limits a daily chore to these weekdays ("weekdays" is 1 to 5). */
  weekdays?: string[];
  dueDate?: string;
  dueTime?: string;
};

/**
 * Turns what an app sent into the schedule to store, or throws a sentence the person can read.
 * Apps that predate repeat rules send only `cadence`, `weekDay` and `dueDate`.
 */
export function resolveChoreSchedule(input: ChoreScheduleInput): ChoreSchedule & {
  cadence: "daily" | "weekly";
} {
  const repeatUnit: ChoreRepeatUnit =
    input.repeatUnit ?? (input.cadence === "weekly" ? "week" : "day");
  const repeatInterval =
    repeatUnit === "none" ? 1 : (input.repeatInterval ?? 1);
  if (
    !Number.isInteger(repeatInterval) ||
    repeatInterval < 1 ||
    repeatInterval > MAX_INTERVAL
  ) {
    throw new Error(`Repeat every 1 to ${MAX_INTERVAL}.`);
  }

  const dueDate = input.dueDate ?? null;
  if (dueDate !== null && !isRealDate(dueDate)) {
    throw new Error("That is not a real date.");
  }
  const dueTime = input.dueTime ?? null;
  if (dueTime !== null && !TIME_PATTERN.test(dueTime)) {
    throw new Error("That is not a valid time.");
  }

  if (repeatUnit === "none" && dueTime && !dueDate) {
    throw new Error("Pick a date to set a time on a chore that does not repeat.");
  }
  // These count from the date, so without one there is nothing to count from.
  const needsDate =
    repeatUnit === "month" ||
    repeatUnit === "year" ||
    (repeatInterval > 1 && repeatUnit !== "none");
  if (needsDate && !dueDate) {
    throw new Error("Pick the date this chore starts on.");
  }

  let days = ALL_DAYS;
  if (repeatUnit === "week") {
    const weekDay =
      input.weekDay ??
      (dueDate ? String(weekdayOf(dayNumber(dueDate))) : "1");
    days = /^[0-6]$/.test(weekDay) ? weekDay : "1";
  } else if (repeatUnit === "day" && repeatInterval === 1 && input.weekdays) {
    const chosen = [...new Set(input.weekdays)]
      .filter((day) => /^[0-6]$/.test(day))
      .sort();
    if (chosen.length === 0) throw new Error("Pick at least one day.");
    days = chosen.join(",");
  }

  return {
    cadence: repeatUnit === "day" ? "daily" : "weekly",
    repeatUnit,
    repeatInterval,
    days,
    dueDate,
    dueTime,
  };
}

/** Whether a repeating chore has an occurrence on this date. */
export function isChoreOccurrence(
  schedule: ChoreSchedule,
  localDate: string,
): boolean {
  const { repeatUnit, days, dueDate } = schedule;
  const interval = Math.max(1, schedule.repeatInterval);
  if (repeatUnit === "none") return false;

  const date = dayNumber(localDate);
  const start = dueDate ? dayNumber(dueDate) : null;
  if (start !== null && date < start) return false;

  if (repeatUnit === "day") {
    if (interval > 1) return start !== null && (date - start) % interval === 0;
    return days.split(",").includes(String(weekdayOf(date)));
  }

  if (repeatUnit === "week") {
    if (weekdayOf(date) !== Number(weeklyChoreDay(days))) return false;
    if (interval === 1 || start === null) return true;
    return ((mondayOf(date) - mondayOf(start)) / 7) % interval === 0;
  }

  if (start === null) return false;
  const now = parts(date);
  const first = parts(start);
  const months = (now.year - first.year) * 12 + (now.month - first.month);
  if (repeatUnit === "month") {
    if (months % interval !== 0) return false;
  } else if (now.month !== first.month || (now.year - first.year) % interval !== 0) {
    return false;
  }
  // A chore that starts on the 31st falls on the last day of a shorter month.
  return now.day === Math.min(first.day, daysInMonth(now.year, now.month));
}

/** The first date after `localDate` a repeating chore falls on, or null if it never does again. */
export function nextChoreOccurrence(
  schedule: ChoreSchedule,
  localDate: string,
): string | null {
  const interval = Math.max(1, schedule.repeatInterval);
  const reach = {
    none: 0,
    day: interval,
    week: 7 * interval,
    month: 31 * interval,
    year: 366 * interval + 1,
  }[schedule.repeatUnit];
  const from = dayNumber(localDate);
  for (let offset = 1; offset <= reach + 7; offset++) {
    const candidate = dateFromDayNumber(from + offset);
    if (isChoreOccurrence(schedule, candidate)) return candidate;
  }
  return null;
}

/**
 * Chores are checked off once per period: a one-off once, a weekly chore by ISO week (as it
 * always has been) and anything else by the date it fell on.
 */
export function chorePeriodKey(
  schedule: Pick<ChoreSchedule, "repeatUnit" | "repeatInterval">,
  localDate: string,
): string {
  if (schedule.repeatUnit === "none") return "once";
  if (schedule.repeatUnit === "week" && schedule.repeatInterval === 1) {
    return weekKey(new Date(`${localDate}T12:00:00`));
  }
  return localDate;
}

/** The pattern a period key must have for a chore, so nothing is saved for a period that can't exist. */
export function chorePeriodKeyPattern(
  schedule: Pick<ChoreSchedule, "repeatUnit" | "repeatInterval">,
): RegExp {
  if (schedule.repeatUnit === "none") return /^once$/;
  if (schedule.repeatUnit === "week" && schedule.repeatInterval === 1) {
    return /^\d{4}-W(0[1-9]|[1-4]\d|5[0-3])$/;
  }
  return /^\d{4}-\d{2}-\d{2}$/;
}

export type ChoreState = {
  periodKey: string;
  completed: boolean;
  /** Whether it belongs on the list for `localDate`: due that day, or a one-off that is open. */
  dueToday: boolean;
  /** Past its date (or today's time) and still not done. */
  overdue: boolean;
  /** For a chore not due today, the next date it is. */
  nextDueDate: string | null;
};

/**
 * What a chore looks like on a given day. `completionFor` finds the check-off for a period key
 * (this chore's own, for that day), if there is one. A one-off that was finished on an earlier
 * day is no longer listed; it stays in the full list, checked off.
 */
export function choreState(
  chore: ChoreSchedule,
  options: {
    localDate: string;
    timezone: string;
    now?: Date;
    completionFor?: (periodKey: string) => { completedAt: Date } | undefined;
  },
): ChoreState {
  const { localDate, timezone } = options;
  const now = options.now ?? new Date();
  const periodKey = chorePeriodKey(chore, localDate);
  const completion = options.completionFor?.(periodKey);
  const completed = Boolean(completion);

  let dueToday: boolean;
  let nextDueDate: string | null = null;
  if (chore.repeatUnit === "none") {
    if (completion) {
      dueToday = localDateIn(timezone, completion.completedAt) === localDate;
    } else {
      dueToday = chore.dueDate === null || chore.dueDate <= localDate;
      if (!dueToday) nextDueDate = chore.dueDate;
    }
  } else {
    dueToday = isChoreOccurrence(chore, localDate);
    if (!dueToday) nextDueDate = nextChoreOccurrence(chore, localDate);
  }

  return {
    periodKey,
    completed,
    dueToday,
    overdue: !completed && isChoreOverdue(chore, localDate, timezone, now),
    nextDueDate,
  };
}

function isChoreOverdue(
  chore: ChoreSchedule,
  localDate: string,
  timezone: string,
  now: Date,
): boolean {
  const today = localDateIn(timezone, now);
  if (chore.repeatUnit === "none") {
    if (!chore.dueDate) return false;
    if (chore.dueDate < localDate) return true;
    return chore.dueDate === localDate && pastDueTime(chore, localDate, today, timezone, now);
  }
  // A repeating chore is never behind on an earlier turn (that turn is gone); it is late only
  // when today's has a time and the time has passed.
  return (
    isChoreOccurrence(chore, localDate) &&
    pastDueTime(chore, localDate, today, timezone, now)
  );
}

function pastDueTime(
  chore: ChoreSchedule,
  localDate: string,
  today: string,
  timezone: string,
  now: Date,
): boolean {
  if (!chore.dueTime || localDate !== today) return false;
  const clock = new Intl.DateTimeFormat("en-GB", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).format(now);
  return clock > chore.dueTime;
}

/** A timed chore on a coming day, so the phone can schedule its reminder before that day arrives. */
export type UpcomingChore = {
  id: string;
  title: string;
  profileId: string | null;
  /** The day it falls on ("YYYY-MM-DD"). */
  date: string;
  dueTime: string;
  periodKey: string;
};

/** How many days after today the phone is told about. */
export const UPCOMING_CHORE_DAYS = 3;

/**
 * The chores with a time that fall on each of the next few days, for reminders. Today is left to
 * the dashboard's own chore list, which knows what has been done. A one-off that is already done
 * is left out; a repeating chore's future turns can't have been.
 */
export function upcomingTimedChores(
  chores: Array<ChoreSchedule & { id: string; title: string; profileId: string | null }>,
  options: { localDate: string; days?: number; isDone: (choreId: string, periodKey: string) => boolean },
): UpcomingChore[] {
  const days = options.days ?? UPCOMING_CHORE_DAYS;
  const today = dayNumber(options.localDate);
  const found: UpcomingChore[] = [];
  for (const chore of chores) {
    if (!chore.dueTime) continue;
    for (let offset = 1; offset <= days; offset++) {
      const date = dateFromDayNumber(today + offset);
      const falls =
        chore.repeatUnit === "none"
          ? chore.dueDate === date
          : isChoreOccurrence(chore, date);
      if (!falls) continue;
      const periodKey = chorePeriodKey(chore, date);
      if (options.isDone(chore.id, periodKey)) continue;
      found.push({
        id: chore.id,
        title: chore.title,
        profileId: chore.profileId,
        date,
        dueTime: chore.dueTime,
        periodKey,
      });
    }
  }
  return found.sort((a, b) =>
    `${a.date} ${a.dueTime}`.localeCompare(`${b.date} ${b.dueTime}`),
  );
}
