import { and, eq, gte } from "drizzle-orm";
import { db } from "@/db/client";
import { routineCompletions, routines, routineSteps } from "@/db/schema";
import { localDateIn } from "@/lib/dates";
import {
  STREAK_LOOKBACK_DAYS,
  addDays,
  computeStreak,
  stepStartDate,
  type StreakResult,
  type StreakStep,
} from "@/lib/streaks";

export type RoutineStreak = StreakResult & {
  /** The child (or adult) the routines belong to; null for routines shared by the household. */
  profileId: string | null;
};

/** Current and best routine streaks for every profile that has routines. */
export async function loadRoutineStreaks(
  householdId: string,
  timezone: string,
  today: string,
): Promise<RoutineStreak[]> {
  const windowStart = addDays(today, -STREAK_LOOKBACK_DAYS);

  const [routineRows, stepRows, completionRows] = await Promise.all([
    db.select().from(routines).where(eq(routines.householdId, householdId)),
    db
      .select({
        id: routineSteps.id,
        routineId: routineSteps.routineId,
        createdAt: routineSteps.createdAt,
      })
      .from(routineSteps)
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(eq(routines.householdId, householdId)),
    db
      .select({
        stepId: routineCompletions.stepId,
        localDate: routineCompletions.localDate,
      })
      .from(routineCompletions)
      .innerJoin(routineSteps, eq(routineCompletions.stepId, routineSteps.id))
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(
        and(
          eq(routines.householdId, householdId),
          gte(routineCompletions.localDate, windowStart),
        ),
      ),
  ]);

  const completions = new Map<string, Set<string>>();
  for (const row of completionRows) {
    const dates = completions.get(row.stepId) ?? new Set<string>();
    dates.add(row.localDate);
    completions.set(row.stepId, dates);
  }

  const routineById = new Map(routineRows.map((routine) => [routine.id, routine]));
  const groups = new Map<string | null, StreakStep[]>();
  for (const step of stepRows) {
    const routine = routineById.get(step.routineId);
    if (!routine) continue;
    const dates = completions.get(step.id);
    const start = stepStartDate({
      createdDate: step.createdAt ? localDateIn(timezone, step.createdAt) : null,
      firstCompletionDate: dates ? [...dates].sort()[0] : null,
      routineCreatedDate: localDateIn(timezone, routine.createdAt),
    });
    const group = groups.get(routine.profileId) ?? [];
    group.push({ id: step.id, days: routine.days, startDate: start });
    groups.set(routine.profileId, group);
  }

  return [...groups.entries()].map(([profileId, steps]) => ({
    profileId,
    ...computeStreak({ steps, completions, today }),
  }));
}
