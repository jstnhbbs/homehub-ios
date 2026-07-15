import type { ParsedRecipe } from "./types";

type JsonObject = Record<string, unknown>;

const NUTRITION_LABELS: Record<string, string> = {
  calories: "Calories",
  carbohydrateContent: "Carbs",
  cholesterolContent: "Cholesterol",
  fatContent: "Fat",
  fiberContent: "Fiber",
  proteinContent: "Protein",
  saturatedFatContent: "Saturated fat",
  servingSize: "Serving size",
  sodiumContent: "Sodium",
  sugarContent: "Sugar",
  transFatContent: "Trans fat",
  unsaturatedFatContent: "Unsaturated fat",
};

export function stripHtml(value: string) {
  return value
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/\s+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function formatDuration(value: unknown) {
  if (typeof value !== "string" || !value.startsWith("P")) return undefined;
  const match = value.match(
    /^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/,
  );
  if (!match) return value;

  const days = Number(match[1] ?? 0);
  const hours = Number(match[2] ?? 0);
  const minutes = Number(match[3] ?? 0);
  const parts = [];
  if (days) parts.push(`${days} day${days === 1 ? "" : "s"}`);
  if (hours) parts.push(`${hours} hr${hours === 1 ? "" : "s"}`);
  if (minutes) parts.push(`${minutes} min`);
  return parts.join(" ") || undefined;
}

function asText(value: unknown) {
  if (typeof value === "string") return stripHtml(value);
  if (typeof value === "number") return String(value);
  return undefined;
}

function asStringList(value: unknown): string[] {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value.flatMap((item) => asStringList(item));
  }
  if (typeof value === "string") {
    const text = stripHtml(value);
    return text ? [text] : [];
  }
  if (typeof value === "object" && value !== null) {
    const item = value as JsonObject;
    if (Array.isArray(item.itemListElement)) {
      return asStringList(item.itemListElement);
    }
    const text =
      asText(item.text) ??
      asText(item.name) ??
      asText(item.item) ??
      asText(item.description);
    return text ? [text] : [];
  }
  return [];
}

function recipeType(value: unknown) {
  if (value === "Recipe") return true;
  return Array.isArray(value) && value.includes("Recipe");
}

function findRecipeNodes(data: unknown): JsonObject[] {
  if (Array.isArray(data)) {
    return data.flatMap((item) => findRecipeNodes(item));
  }
  if (typeof data !== "object" || data === null) return [];

  const node = data as JsonObject;
  if (Array.isArray(node["@graph"])) {
    return findRecipeNodes(node["@graph"]);
  }
  if (recipeType(node["@type"])) {
    return [node];
  }
  return [];
}

export function extractJsonLdBlocks(html: string) {
  const blocks: unknown[] = [];
  const pattern =
    /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

  for (const match of html.matchAll(pattern)) {
    const raw = match[1]?.trim();
    if (!raw) continue;
    try {
      blocks.push(JSON.parse(raw));
    } catch {
      // Ignore malformed JSON-LD blocks.
    }
  }
  return blocks;
}

function parseNutrition(value: unknown) {
  if (!value || typeof value !== "object") return undefined;
  const nutrition: Record<string, string> = {};
  for (const [key, label] of Object.entries(NUTRITION_LABELS)) {
    const text = asText((value as JsonObject)[key]);
    if (text) nutrition[label] = text;
  }
  return Object.keys(nutrition).length ? nutrition : undefined;
}

function parseImage(value: unknown): string | undefined {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) {
    for (const item of value) {
      const image = parseImage(item);
      if (image) return image;
    }
    return undefined;
  }
  if (typeof value === "object" && value !== null) {
    return asText((value as JsonObject).url);
  }
  return undefined;
}

function parseYield(value: unknown) {
  if (typeof value === "string" || typeof value === "number") {
    return asText(value);
  }
  if (Array.isArray(value)) {
    return value.map((item) => asText(item)).filter(Boolean).join(", ");
  }
  return undefined;
}

export function parseRecipeFromJsonLd(
  blocks: unknown[],
  sourceUrl?: string,
): ParsedRecipe | null {
  const recipe = blocks.flatMap((block) => findRecipeNodes(block))[0];
  if (!recipe) return null;

  const title = asText(recipe.name);
  if (!title) return null;

  const ingredients = asStringList(recipe.recipeIngredient).filter(Boolean);
  const directions = asStringList(recipe.recipeInstructions).filter(Boolean);
  if (!ingredients.length && !directions.length) return null;

  return {
    title,
    description: asText(recipe.description),
    servings: parseYield(recipe.recipeYield),
    prepTime: formatDuration(recipe.prepTime),
    cookTime: formatDuration(recipe.cookTime),
    totalTime: formatDuration(recipe.totalTime),
    ingredients,
    directions,
    nutrition: parseNutrition(recipe.nutrition),
    imageUrl: parseImage(recipe.image),
    sourceUrl,
  };
}

export function parseRecipeFromHtml(html: string, sourceUrl?: string) {
  return parseRecipeFromJsonLd(extractJsonLdBlocks(html), sourceUrl);
}
