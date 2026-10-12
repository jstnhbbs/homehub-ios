export const PROFILE_COLORS = [
  { value: "#d87861", label: "Coral" },
  { value: "#6689a3", label: "Blue" },
  { value: "#4f7c6d", label: "Sage" },
  { value: "#b07aa1", label: "Plum" },
  { value: "#d19b45", label: "Gold" },
  { value: "#5f8f8b", label: "Teal" },
  { value: "#8c7ca8", label: "Lavender" },
  { value: "#b86f4d", label: "Terracotta" },
  { value: "#7f8757", label: "Olive" },
] as const;

export function isProfileColor(value: string) {
  return PROFILE_COLORS.some((color) => color.value === value);
}

/**
 * The color a new profile should start with: the first one in the palette that nobody in the household has,
 * so two people added in a row don't both come out the same. Once all nine are taken, the one used least
 * (the first of those in palette order), so repeats are spread out rather than piled on one color.
 */
export function pickProfileColor(usedColors: ReadonlyArray<string | null | undefined>): string {
  const counts = new Map<string, number>();
  for (const color of usedColors) {
    if (!color) continue;
    const key = color.toLowerCase();
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  let best: string = PROFILE_COLORS[0].value;
  let bestCount = Number.POSITIVE_INFINITY;
  for (const { value } of PROFILE_COLORS) {
    const count = counts.get(value.toLowerCase()) ?? 0;
    if (count === 0) return value;
    if (count < bestCount) {
      best = value;
      bestCount = count;
    }
  }
  return best;
}
