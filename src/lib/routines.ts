export const ALL_ROUTINE_DAYS = "0,1,2,3,4,5,6";

/**
 * The weekdays a routine runs, as "1,3,5" (0 = Sunday), sorted and without repeats. Throws a
 * sentence the person can read when none is left, since a routine that never runs can't be
 * what was meant.
 */
export function normalizeRoutineDays(days: string): string {
  const chosen = [
    ...new Set(
      days
        .split(",")
        .map((day) => day.trim())
        .filter((day) => /^[0-6]$/.test(day))
    ),
  ].sort();
  if (chosen.length === 0) throw new Error("Pick at least one day.");
  return chosen.join(",");
}

/** Whether a routine with these days runs on a calendar date ("YYYY-MM-DD"). */
export function routineRunsOn(days: string, localDate: string): boolean {
  const [year, month, day] = localDate.split("-").map(Number);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return days.split(",").includes(String(weekday));
}

export type StepPairing = {
  /** The existing step whose row (and check-off history) this step keeps, or null for a new one. */
  id: string | null;
  label: string;
};

/**
 * Decides which existing step each incoming label belongs to, so changing the order of a routine
 * moves its steps instead of relabelling them. A step keeps its row when its label is unchanged,
 * wherever it moved to. Labels that match nothing (new or reworded) take over the leftover rows in
 * order, so rewording a step still keeps its history, as it always has. Rows nothing takes are
 * returned in `removed`.
 */
export function pairRoutineSteps(
  existing: Array<{ id: string; label: string }>,
  incoming: string[]
): { pairs: StepPairing[]; removed: string[] } {
  const used = new Set<string>();
  const matched: Array<string | null> = incoming.map((label) => {
    const found = existing.find(
      (step) => !used.has(step.id) && step.label === label
    );
    if (found) used.add(found.id);
    return found?.id ?? null;
  });

  const spare = existing
    .filter((step) => !used.has(step.id))
    .map((step) => step.id);
  const pairs = incoming.map((label, index) => {
    const id = matched[index] ?? spare.shift() ?? null;
    return { id, label };
  });
  return { pairs, removed: spare };
}
