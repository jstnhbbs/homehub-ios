/**
 * Routine streaks: how many days in a row a child finished every routine step scheduled for them.
 *
 * Rules:
 * - A day counts only if at least one step was scheduled that day. Days with nothing scheduled
 *   (for example a weekday-only routine on a weekend) neither break nor extend a streak.
 * - A counted day is complete when every scheduled step was completed.
 * - Today being unfinished does not break a streak; it is still in progress. A missed day
 *   breaks it once that day has passed.
 * - A step only counts from its start date, so adding a step later never erases a streak.
 *
 * Dates are `yyyy-MM-dd` strings. The weekday of a calendar date does not depend on the time
 * zone, so no zone handling is needed here (callers convert timestamps to local dates).
 */

export type StreakStep = {
  id: string;
  /** Weekdays the step is scheduled, "0,1,2,3,4,5,6" with 0 = Sunday. */
  days: string;
  /** First local date on which the step counts. */
  startDate: string;
};

export type StreakResult = {
  current: number;
  best: number;
  completedToday: boolean;
  /** Steps are scheduled today and not all done yet. */
  todayPending: boolean;
};

export const STREAK_LOOKBACK_DAYS = 400;

export function addDays(date: string, days: number) {
  const [year, month, day] = date.split("-").map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day + days));
  return shifted.toISOString().slice(0, 10);
}

function weekday(date: string) {
  const [year, month, day] = date.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

/**
 * The first date a step counts. Steps created after streaks existed carry their own creation
 * date. Older steps use their first recorded completion (so a step added to an old routine does
 * not retroactively break the past), or the routine's creation date if never completed.
 */
export function stepStartDate(input: {
  createdDate: string | null;
  firstCompletionDate: string | null;
  routineCreatedDate: string;
}) {
  return input.createdDate ?? input.firstCompletionDate ?? input.routineCreatedDate;
}

export function computeStreak(input: {
  steps: StreakStep[];
  /** Step id -> dates that step was completed. */
  completions: Map<string, Set<string>>;
  today: string;
  lookbackDays?: number;
}): StreakResult {
  const { steps, completions, today } = input;
  const empty = { current: 0, best: 0, completedToday: false, todayPending: false };
  if (steps.length === 0) return empty;

  const earliest = steps.reduce((min, step) => (step.startDate < min ? step.startDate : min), today);
  const limit = addDays(today, -(input.lookbackDays ?? STREAK_LOOKBACK_DAYS));
  const first = earliest > limit ? earliest : limit;

  type Day = { date: string; counted: boolean; complete: boolean };
  const days: Day[] = [];
  for (let date = first; date <= today; date = addDays(date, 1)) {
    const dow = String(weekday(date));
    const scheduled = steps.filter(
      (step) => step.startDate <= date && step.days.split(",").includes(dow),
    );
    days.push({
      date,
      counted: scheduled.length > 0,
      complete:
        scheduled.length > 0 &&
        scheduled.every((step) => completions.get(step.id)?.has(date) ?? false),
    });
  }

  let best = 0;
  let run = 0;
  for (const day of days) {
    if (!day.counted) continue;
    run = day.complete ? run + 1 : 0;
    best = Math.max(best, run);
  }

  let current = 0;
  for (let index = days.length - 1; index >= 0; index -= 1) {
    const day = days[index];
    if (!day.counted) continue;
    if (day.date === today && !day.complete) continue;
    if (!day.complete) break;
    current += 1;
  }

  const todayEntry = days[days.length - 1];
  return {
    current,
    best,
    completedToday: todayEntry?.counted === true && todayEntry.complete,
    todayPending: todayEntry?.counted === true && !todayEntry.complete,
  };
}
