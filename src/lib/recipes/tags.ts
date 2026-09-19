/**
 * Recipe tags: a short list of labels per recipe, such as a meal type (Dinner) and a main
 * protein (Chicken). The presets get consistent spelling; anything else is kept as a custom tag.
 */

export const MEAL_TAGS = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"] as const;
export const PROTEIN_TAGS = [
  "Chicken",
  "Beef",
  "Pork",
  "Turkey",
  "Fish",
  "Seafood",
  "Vegetarian",
] as const;

export const MAX_TAGS = 12;
export const MAX_TAG_LENGTH = 24;

const PRESETS = new Map<string, string>(
  [...MEAL_TAGS, ...PROTEIN_TAGS].map((tag) => [tag.toLowerCase(), tag]),
);

// Capitalizes the first letter of each space-separated word. (\b is not Unicode-aware, so it
// would split "crème" in the middle.) Hyphenated words keep their casing: "One-pot".
function titleCase(value: string) {
  return value.replace(/(^|\s)(\p{L})/gu, (_match, space: string, letter: string) => space + letter.toUpperCase());
}

/** Trims, fixes casing, drops duplicates (ignoring case), and enforces the limits. */
export function normalizeTags(input: readonly string[]): string[] {
  const seen = new Set<string>();
  const tags: string[] = [];
  for (const raw of input) {
    const cleaned = raw.replace(/\s+/g, " ").trim().slice(0, MAX_TAG_LENGTH).trim();
    if (!cleaned) continue;
    const key = cleaned.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    tags.push(PRESETS.get(key) ?? titleCase(cleaned));
    if (tags.length === MAX_TAGS) break;
  }
  return tags;
}

const MEAL_CATEGORY_RULES: Array<[RegExp, (typeof MEAL_TAGS)[number]]> = [
  [/\b(breakfast|brunch)\b/i, "Breakfast"],
  [/\blunch\b/i, "Lunch"],
  [/\b(dinner|supper|main course|main dish|entr[eé]e)\b/i, "Dinner"],
  [/\bdessert\b/i, "Dessert"],
  [/\b(snack|appetizer|starter)\b/i, "Snack"],
];

// A protein only counts when it is not just part of a broth or seasoning.
const NOT_THE_MEAT = "(?!\\s*(?:broth|stock|bouillon|base|seasoning|flavou?red|flavou?r))";

const PROTEIN_RULES: Array<[RegExp, (typeof PROTEIN_TAGS)[number]]> = [
  [new RegExp(`\\bchicken\\b${NOT_THE_MEAT}`, "i"), "Chicken"],
  [new RegExp(`\\b(beef|steak|brisket|sirloin|ribeye)\\b${NOT_THE_MEAT}`, "i"), "Beef"],
  [/\b(pork|bacon|ham|sausage|chorizo|pancetta|prosciutto)\b/i, "Pork"],
  [new RegExp(`\\bturkey\\b${NOT_THE_MEAT}`, "i"), "Turkey"],
  [/\b(salmon|tuna|cod|tilapia|trout|halibut|haddock|mahi[- ]mahi|sea bass|fish)\b(?!\s*sauce)/i, "Fish"],
  [/\b(shrimp|prawns?|crab|lobster|scallops?|clams?|mussels?|oysters?)\b/i, "Seafood"],
];

/** Guesses tags from a page's recipe category and from the ingredient list. */
export function suggestTags(input: {
  title: string;
  ingredients: readonly string[];
  categories?: readonly string[];
}): string[] {
  const categories = (input.categories ?? []).join(" ");
  const meals = MEAL_CATEGORY_RULES.filter(([pattern]) => pattern.test(categories)).map(([, tag]) => tag);

  const text = [input.title, ...input.ingredients].join("\n");
  const proteins = PROTEIN_RULES.filter(([pattern]) => pattern.test(text)).map(([, tag]) => tag);

  return normalizeTags([...meals, ...proteins]);
}

/** Meal-type tags that match a planner slot ("dinner" -> "Dinner"). */
export function mealTagForSlot(slot: string) {
  return MEAL_TAGS.find((tag) => tag.toLowerCase() === slot.toLowerCase());
}
