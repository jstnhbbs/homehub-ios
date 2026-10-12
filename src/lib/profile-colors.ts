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

/**
 * The color a guest's profile starts with: a quiet grey (the app shows it as Slate), since a guest mostly looks
 * and logs and shouldn't use up one of the family's colors. It is kept out of `PROFILE_COLORS` on purpose: the
 * automatic color for a celebration is picked from that list by position (`colorForBirthdayName`) and
 * `pickProfileColor` hands out only those nine, so adding to it would change colors people already have.
 * It can still be chosen from the picker, for anyone, through `PROFILE_COLOR_CHOICES`.
 */
export const GUEST_PROFILE_COLOR = { value: "#8e939b", label: "Grey" } as const;

/** Everything a profile or celebration may be given: the nine family colors, then the guest grey. */
export const PROFILE_COLOR_CHOICES = [...PROFILE_COLORS, GUEST_PROFILE_COLOR] as const;

export function isProfileColor(value: string) {
  return PROFILE_COLOR_CHOICES.some((color) => color.value === value);
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
