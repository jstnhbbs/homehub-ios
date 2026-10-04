export function parseSnackOptions(value?: string | null) {
  if (!value) return [];
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

export function serializeSnackOptions(lines: string[]) {
  return lines.join("\n");
}

/** Unchecked snacks first (original order), then checked snacks at the bottom. */
export function sortSnackOptions(
  items: string[],
  eaten: ReadonlySet<string>,
) {
  const pending = items.filter((item) => !eaten.has(item));
  const done = items.filter((item) => eaten.has(item));
  return [...pending, ...done];
}

export type SnackCompletionRow = { snackLabel: string; profileId: string };

/**
 * The profile id stored for the household-wide checklist. A real child's id is never empty, so
 * this can share a column with per-child rows without a nullable primary key.
 */
export const SHARED_SNACK_PROFILE = "";

/**
 * Which snacks count as eaten, as a flat list of labels.
 *
 * Household-wide mode is just the shared rows. Per-child mode counts a snack as eaten once every
 * child has had it, which is also what an app version that predates per-child snacks will show.
 * Rows for children who no longer exist are ignored, so deleting a profile cannot leave a snack
 * stuck half-eaten.
 */
export function snackEatenLabels(
  rows: readonly SnackCompletionRow[],
  perChild: boolean,
  childIds: readonly string[],
): string[] {
  if (!perChild) {
    return [
      ...new Set(
        rows
          .filter((row) => row.profileId === SHARED_SNACK_PROFILE)
          .map((row) => row.snackLabel),
      ),
    ];
  }
  if (childIds.length === 0) return [];
  const byLabel = new Map<string, Set<string>>();
  for (const row of rows) {
    if (!childIds.includes(row.profileId)) continue;
    const seen = byLabel.get(row.snackLabel) ?? new Set<string>();
    seen.add(row.profileId);
    byLabel.set(row.snackLabel, seen);
  }
  return [...byLabel.entries()]
    .filter(([, seen]) => childIds.every((id) => seen.has(id)))
    .map(([label]) => label);
}
