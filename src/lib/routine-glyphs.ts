export const ROUTINE_GLYPHS = [
  { glyph: "🪥", label: "Brush teeth", terms: ["brush", "teeth", "tooth"] },
  { glyph: "🚽", label: "Potty", terms: ["potty", "toilet", "bathroom", "pee"] },
  { glyph: "🧼", label: "Wash hands", terms: ["wash", "hands", "soap"] },
  { glyph: "🛁", label: "Bath", terms: ["bath", "shower"] },
  { glyph: "👕", label: "Get dressed", terms: ["clothes", "shirt", "pajamas", "dressed"] },
  { glyph: "👟", label: "Shoes", terms: ["shoes", "socks"] },
  { glyph: "🎒", label: "Backpack", terms: ["backpack", "pack", "school bag"] },
  { glyph: "🍽️", label: "Meal", terms: ["eat", "breakfast", "dinner", "lunch"] },
  { glyph: "💧", label: "Water", terms: ["water", "drink"] },
  { glyph: "🐶", label: "Dog", terms: ["dog", "puppy"] },
  { glyph: "🥣", label: "Pet food", terms: ["food", "feed", "kibble"] },
  { glyph: "📚", label: "Read", terms: ["read", "book", "homework"] },
  { glyph: "🧸", label: "Clean up toys", terms: ["toy", "clean up", "pick up"] },
  { glyph: "🛏️", label: "Make bed", terms: ["bed", "sleep"] },
  { glyph: "💊", label: "Medicine", terms: ["medicine", "vitamin"] },
  { glyph: "🧴", label: "Lotion", terms: ["lotion", "sunscreen"] },
  { glyph: "🧦", label: "Laundry", terms: ["laundry", "hamper"] },
  { glyph: "🧹", label: "Sweep", terms: ["sweep", "vacuum"] },
  { glyph: "🗑️", label: "Trash", terms: ["trash", "garbage"] },
  { glyph: "⭐", label: "Other", terms: [] },
] as const;

const explicitGlyphPattern = /^(\p{Extended_Pictographic}(?:\uFE0F)?)(?:\s+|$)/u;

export function routineStepDisplay(label: string) {
  const trimmed = label.trim();
  const explicit = trimmed.match(explicitGlyphPattern);
  if (explicit?.[1]) {
    return {
      glyph: explicit[1],
      label: trimmed.slice(explicit[0].length).trim() || trimmed,
    };
  }

  const normalized = trimmed.toLowerCase();
  const match = ROUTINE_GLYPHS.find((rule) =>
    rule.terms.some((term) => normalized.includes(term)),
  );
  return { glyph: match?.glyph ?? "⭐", label: trimmed };
}

export function routineStepStorageValue({
  glyph,
  label,
}: {
  glyph: string;
  label: string;
}) {
  const normalizedLabel = label.trim();
  const inferred = routineStepDisplay(normalizedLabel);
  if (!normalizedLabel) return "";
  if (glyph === inferred.glyph) return normalizedLabel;
  return `${glyph} ${normalizedLabel}`;
}
