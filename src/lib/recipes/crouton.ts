import { z } from "zod";
import { MAX_DIRECTION_LINE, MAX_INGREDIENT_LINE, MAX_NOTES, MAX_TITLE } from "./limits";
import { normalizeTags, suggestTags } from "./tags";
import { webUrl } from "@/lib/web-url";

/**
 * Turns a recipe exported from Crouton (a `.crumb` file, which is JSON) into one of ours.
 *
 * The phone reads the files and sends only the text fields. The photos, which make a file
 * several megabytes, go separately and resized. Everything about how a Crouton recipe maps onto
 * ours lives here so it can be tested without a device.
 *
 * What maps and how:
 *   name                        -> title
 *   ingredients (amount + unit) -> one line each, "1 ½ cups carrots, chopped"
 *   steps                       -> directions, leading "1." numbering removed (the app numbers)
 *   section rows                -> "## Heading" lines in ingredients or directions
 *   duration / cookingDuration  -> prep time / cook time (Crouton stores minutes)
 *   serves                      -> servings
 *   neutritionalInfo            -> nutrition, for the lines that read as a nutrient and an amount
 *   notes                       -> notes
 *   webLink                     -> source link
 *   tags                        -> tags, with the same protein suggestions web imports get
 * Not carried over: rating, scale, difficulty, folders, the public-recipe flag, the thumbnail.
 */

/** The heading marker used in ingredient and direction lists. Rendered as a heading, never numbered. */
export const HEADING_PREFIX = "## ";


const quantitySchema = z.object({
  quantityType: z.string().max(40).nullish(),
  amount: z.number().finite().min(0).max(1_000_000).nullish(),
  secondaryAmount: z.number().finite().min(0).max(1_000_000).nullish(),
});

// Unknown fields (the embedded photos above all) are dropped by parsing, not carried around.
export const croutonRecipeSchema = z.object({
  uuid: z.string().trim().min(1).max(100),
  name: z.string().trim().min(1).max(500),
  webLink: z.string().max(2048).nullish(),
  sourceName: z.string().max(200).nullish(),
  serves: z.number().finite().min(0).max(100_000).nullish(),
  duration: z.number().finite().min(0).max(100_000).nullish(),
  cookingDuration: z.number().finite().min(0).max(100_000).nullish(),
  neutritionalInfo: z.string().max(10_000).nullish(),
  notes: z.string().max(40_000).nullish(),
  ingredients: z
    .array(
      z.object({
        order: z.number().finite().nullish(),
        ingredient: z.object({ name: z.string().max(2000) }),
        quantity: quantitySchema.nullish(),
      }),
    )
    .max(300),
  steps: z
    .array(
      z.object({
        order: z.number().finite().nullish(),
        step: z.string().max(20_000),
        isSection: z.boolean().nullish(),
      }),
    )
    .max(300),
  tags: z.array(z.object({ name: z.string().max(200) })).max(100).nullish(),
});

export type CroutonRecipe = z.infer<typeof croutonRecipeSchema>;

export type ImportedRecipe = {
  /** Identifies this recipe in the export, so importing the same file twice adds nothing. */
  importKey: string;
  title: string;
  servings?: string;
  prepTime?: string;
  cookTime?: string;
  totalTime?: string;
  ingredients: string[];
  directions: string[];
  nutrition?: Record<string, string>;
  sourceUrl?: string;
  notes?: string;
  tags: string[];
};

// MARK: Amounts and units

const FRACTIONS: Array<[value: number, glyph: string]> = [
  [1 / 8, "⅛"],
  [1 / 4, "¼"],
  [1 / 3, "⅓"],
  [3 / 8, "⅜"],
  [1 / 2, "½"],
  [5 / 8, "⅝"],
  [2 / 3, "⅔"],
  [3 / 4, "¾"],
  [7 / 8, "⅞"],
];

/** 1.5 -> "1 ½", 0.333 -> "⅓", 2 -> "2". Anything that isn't a kitchen fraction stays a short decimal. */
export function formatAmount(amount: number) {
  const whole = Math.floor(amount + 1e-9);
  const fraction = amount - whole;
  if (fraction < 0.015) return String(whole);
  if (fraction > 0.985) return String(whole + 1);
  const match = FRACTIONS.find(([value]) => Math.abs(fraction - value) < 0.015);
  if (match) return whole > 0 ? `${whole} ${match[1]}` : match[1];
  return String(Math.round(amount * 100) / 100);
}

type Unit = { one: string; many: string };
const invariant = (word: string): Unit => ({ one: word, many: word });
const counted = (one: string, many: string): Unit => ({ one, many });

// The spellings are ones the grocery list already recognises, so "2 cups flour" merges with
// "1 cup flour" from another recipe.
const UNITS: Record<string, Unit> = {
  CUP: counted("cup", "cups"),
  TABLESPOON: invariant("tbsp"),
  TEASPOON: invariant("tsp"),
  OUNCE: invariant("oz"),
  FLUIDOUNCE: invariant("fl oz"),
  POUND: invariant("lb"),
  GRAMS: invariant("g"),
  KILOGRAMS: invariant("kg"),
  MILLS: invariant("ml"),
  LITRES: invariant("l"),
  PINT: invariant("pt"),
  QUART: invariant("qt"),
  GALLON: invariant("gal"),
  CAN: counted("can", "cans"),
  BUNCH: counted("bunch", "bunches"),
  PINCH: counted("pinch", "pinches"),
  PACKET: counted("packet", "packets"),
  BOTTLE: counted("bottle", "bottles"),
};

function unitFor(quantityType: string | null | undefined) {
  if (!quantityType || quantityType === "ITEM") return null;
  return UNITS[quantityType] ?? invariant(quantityType.toLowerCase().replace(/_/g, " "));
}

function clip(value: string, limit: number) {
  return value.length <= limit ? value : `${value.slice(0, limit - 1).trimEnd()}…`;
}

function headingText(raw: string) {
  return raw.trim().replace(/:+$/, "").trim();
}

export function formatIngredient(item: CroutonRecipe["ingredients"][number]) {
  const name = item.ingredient.name.replace(/\s+/g, " ").trim();
  if (!name) return null;
  const quantity = item.quantity;

  // A group heading ("Gravy") is stored as an ingredient whose unit is SECTION.
  if (quantity?.quantityType === "SECTION") return `${HEADING_PREFIX}${headingText(name)}`;
  if (quantity?.amount == null) return clip(name, MAX_INGREDIENT_LINE);

  let amount = quantity.amount;
  let secondary = quantity.secondaryAmount ?? undefined;
  let unit = unitFor(quantity.quantityType);
  if (quantity.quantityType === "DECILITER") {
    // No grocery unit for these; millilitres is the same thing in words people use.
    amount *= 100;
    if (secondary !== undefined) secondary *= 100;
    unit = invariant("ml");
  }

  const text = secondary !== undefined && secondary > amount
    ? `${formatAmount(amount)}–${formatAmount(secondary)}`
    : formatAmount(amount);
  const largest = Math.max(amount, secondary ?? 0);
  const word = unit ? (largest > 1 ? unit.many : unit.one) : null;
  return clip([text, word, name].filter(Boolean).join(" "), MAX_INGREDIENT_LINE);
}

// MARK: Times and servings

function formatMinutes(minutes: number) {
  const total = Math.round(minutes);
  if (total <= 0) return undefined;
  if (total < 60) return `${total} min`;
  const hours = Math.floor(total / 60);
  const rest = total % 60;
  return `${hours} hr${hours === 1 ? "" : "s"}${rest ? ` ${rest} min` : ""}`;
}

function formatServings(serves: number | null | undefined) {
  if (!serves || serves <= 0) return undefined;
  const text = Number.isInteger(serves) ? String(serves) : String(Math.round(serves * 10) / 10);
  return `${text} ${serves === 1 ? "serving" : "servings"}`;
}

// MARK: Nutrition

const NUTRITION_ALIASES: Array<[RegExp, string]> = [
  [/^(calories|cal|kcal|energy)$/i, "Calories"],
  [/^(total )?fat$/i, "Fat"],
  [/^saturated( fat)?$/i, "Saturated Fat"],
  [/^trans fat$/i, "Trans Fat"],
  [/^unsaturated fat$/i, "Unsaturated Fat"],
  [/^(total )?carb(s|ohydrates?)?$/i, "Carbohydrates"],
  [/^(dietary )?fib(er|re)$/i, "Fiber"],
  [/^(total )?sugars?$/i, "Sugar"],
  [/^protein$/i, "Protein"],
  [/^cholesterol$/i, "Cholesterol"],
  [/^sodium$/i, "Sodium"],
  [/^potassium$/i, "Potassium"],
  [/^calcium$/i, "Calcium"],
  [/^iron$/i, "Iron"],
  [/^serving size$/i, "Serving Size"],
];

const NUTRITION_NOISE = /^(nutrition facts|amount per serving|\(?per serving\)?|%?\s*daily value|\*|.+-free$)/i;
const AMOUNT = String.raw`\d[\d.,]*\s*(?:kcal|cal|mg|mcg|g|iu|%)?`;

function labelFor(raw: string) {
  const label = raw.replace(/\s+/g, " ").trim().replace(/:$/, "");
  for (const [pattern, name] of NUTRITION_ALIASES) {
    if (pattern.test(label)) return name;
  }
  // "VITAMIN C" -> "Vitamin C", and leave mixed-case labels as written.
  return label === label.toUpperCase()
    ? label.toLowerCase().replace(/(^|\s)(\p{L})/gu, (_m, space: string, letter: string) => space + letter.toUpperCase())
    : label;
}

/**
 * Crouton keeps nutrition as free text copied from a web page, so it arrives as "Fat: 31 g",
 * "Total Fat 21g 26%", "182 kcal", "CALORIES 433KCAL" and the page's own furniture ("Nutrition
 * Facts", "% Daily Value*", "fish-free"). Lines that read as a nutrient and an amount are kept,
 * the rest are dropped rather than guessed at.
 */
export function parseNutrition(text: string | null | undefined) {
  if (!text) return undefined;
  const result: Record<string, string> = {};
  const add = (rawLabel: string, rawValue: string) => {
    const label = labelFor(rawLabel);
    const value = rawValue.replace(/\s+/g, " ").trim();
    if (!label || !value || label.length > 40 || label in result) return;
    result[label] = value;
  };

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim().replace(/,$/, "");
    if (!line || line.length > 80 || NUTRITION_NOISE.test(line)) continue;

    const labelled = /^([^:]+):\s*(.+)$/.exec(line);
    if (labelled) {
      add(labelled[1], labelled[2]);
      continue;
    }
    const bareCalories = new RegExp(`^(${AMOUNT})$`, "i").exec(line);
    if (bareCalories && /kcal|cal/i.test(line)) {
      add("Calories", line);
      continue;
    }
    // "Total Fat 21g 26%" and "Fat 32.4 g (49.9%)": the first amount is the nutrient's.
    const spaced = new RegExp(`^([A-Za-z][A-Za-z ]*?)\\s+(${AMOUNT})(?:\\s.*)?$`, "i").exec(line);
    if (spaced) add(spaced[1], spaced[2]);
  }
  return Object.keys(result).length > 0 ? result : undefined;
}

// MARK: Directions

/** "1. Mix the flour" -> "Mix the flour". Only a number followed by a dot or bracket counts. */
function stripStepNumber(text: string) {
  return text.replace(/^\s*\d{1,2}[.)]\s+/, "");
}

/**
 * Some recipes arrive with a whole numbered list squashed into one step ("1. Mix. 2. Bake.3. Cool.").
 * It is split back into steps only when the text starts at 1 and then counts up 2, 3, ... with each
 * number straight after the end of a sentence, so a stray "serves 2. Add" is never cut.
 */
function splitNumberedRun(text: string) {
  if (!/^\s*1[.)]\s/.test(text)) return [text];
  const parts: string[] = [];
  let rest = text;
  for (let next = 2; next <= 40; next += 1) {
    const match = new RegExp(`([.!?])\\s*${next}[.)]\\s*(?=[A-Z])`).exec(rest);
    if (!match) break;
    parts.push(rest.slice(0, match.index + 1));
    rest = rest.slice(match.index + match[0].length);
  }
  parts.push(rest);
  return parts.map((part) => part.trim()).filter(Boolean);
}

function byOrder<T extends { order?: number | null }>(items: T[]) {
  return items
    .map((item, index) => ({ item, index }))
    .sort((a, b) => (a.item.order ?? a.index) - (b.item.order ?? b.index) || a.index - b.index)
    .map(({ item }) => item);
}

/** Drops headings that have nothing under them, which would otherwise sit alone at the end. */
function withoutEmptyHeadings(lines: string[]) {
  return lines.filter((line, index) => {
    if (!line.startsWith(HEADING_PREFIX)) return true;
    const next = lines[index + 1];
    return next !== undefined && !next.startsWith(HEADING_PREFIX);
  });
}

// MARK: The whole recipe

export function mapCroutonRecipe(recipe: CroutonRecipe): ImportedRecipe {
  const ingredients = withoutEmptyHeadings(
    byOrder(recipe.ingredients)
      .map(formatIngredient)
      .filter((line): line is string => line !== null),
  );

  const directions = withoutEmptyHeadings(
    byOrder(recipe.steps).flatMap((step) => {
      const text = step.step.replace(/\r\n/g, "\n").trim();
      if (!text) return [];
      if (step.isSection) return [`${HEADING_PREFIX}${headingText(text)}`];
      return splitNumberedRun(text).map((part) => clip(stripStepNumber(part), MAX_DIRECTION_LINE));
    }),
  );

  const prep = recipe.duration && recipe.duration > 0 ? recipe.duration : undefined;
  const cook = recipe.cookingDuration && recipe.cookingDuration > 0 ? recipe.cookingDuration : undefined;

  let sourceUrl: string | undefined;
  const link = recipe.webLink?.trim();
  if (link && webUrl.safeParse(link).success) sourceUrl = link;

  const notes = [
    recipe.notes?.trim(),
    // A recipe with no link still says where it came from.
    !sourceUrl && recipe.sourceName?.trim() ? `Source: ${recipe.sourceName.trim()}` : undefined,
  ]
    .filter(Boolean)
    .join("\n\n");

  const title = clip(recipe.name.replace(/\s+/g, " ").trim(), MAX_TITLE);
  const ingredientText = ingredients.filter((line) => !line.startsWith(HEADING_PREFIX));
  const tags = normalizeTags([
    ...(recipe.tags ?? []).map((tag) => tag.name),
    ...suggestTags({ title, ingredients: ingredientText }),
  ]);

  return {
    importKey: `crouton:${recipe.uuid.toLowerCase()}`,
    title,
    servings: formatServings(recipe.serves),
    prepTime: prep ? formatMinutes(prep) : undefined,
    cookTime: cook ? formatMinutes(cook) : undefined,
    totalTime: prep && cook ? formatMinutes(prep + cook) : undefined,
    ingredients,
    directions,
    nutrition: parseNutrition(recipe.neutritionalInfo),
    sourceUrl,
    notes: notes ? clip(notes, MAX_NOTES) : undefined,
    tags,
  };
}
