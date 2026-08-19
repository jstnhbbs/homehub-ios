const GLYPH_RULES = [
  { glyph: "🪥", terms: ["brush", "teeth", "tooth"] },
  { glyph: "🚽", terms: ["potty", "toilet", "bathroom", "pee"] },
  { glyph: "🧼", terms: ["wash", "hands", "soap"] },
  { glyph: "🛁", terms: ["bath", "shower"] },
  { glyph: "👕", terms: ["clothes", "shirt", "pajamas", "dressed"] },
  { glyph: "👟", terms: ["shoes", "socks"] },
  { glyph: "🎒", terms: ["backpack", "pack", "school bag"] },
  { glyph: "🍽️", terms: ["eat", "breakfast", "dinner", "lunch"] },
  { glyph: "💧", terms: ["water", "drink"] },
  { glyph: "🐶", terms: ["dog", "puppy"] },
  { glyph: "🥣", terms: ["food", "feed", "kibble"] },
  { glyph: "📚", terms: ["read", "book", "homework"] },
  { glyph: "🧸", terms: ["toy", "clean up", "pick up"] },
  { glyph: "🛏️", terms: ["bed", "sleep"] },
  { glyph: "💊", terms: ["medicine", "vitamin"] },
  { glyph: "🧴", terms: ["lotion", "sunscreen"] },
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
  const match = GLYPH_RULES.find((rule) =>
    rule.terms.some((term) => normalized.includes(term)),
  );
  return { glyph: match?.glyph ?? "⭐", label: trimmed };
}
