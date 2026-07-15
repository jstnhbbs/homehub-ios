import type { recipes } from "@/db/schema";
import type { ParsedRecipe, StoredRecipe } from "./types";

export function parseJsonArray(value: string) {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed)
      ? parsed.filter((item): item is string => typeof item === "string")
      : [];
  } catch {
    return [];
  }
}

export function parseJsonObject(value: string | null) {
  if (!value) return undefined;
  try {
    const parsed = JSON.parse(value);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return undefined;
    }
    return Object.fromEntries(
      Object.entries(parsed).filter(
        (entry): entry is [string, string] => typeof entry[1] === "string",
      ),
    );
  } catch {
    return undefined;
  }
}

export function serializeRecipeFields(input: {
  ingredients: string[];
  directions: string[];
  nutrition?: Record<string, string>;
}) {
  return {
    ingredients: JSON.stringify(input.ingredients),
    directions: JSON.stringify(input.directions),
    nutrition: input.nutrition ? JSON.stringify(input.nutrition) : null,
  };
}

export function recipeFromRow(row: typeof recipes.$inferSelect): StoredRecipe {
  return {
    id: row.id,
    title: row.title,
    description: row.description ?? undefined,
    servings: row.servings ?? undefined,
    prepTime: row.prepTime ?? undefined,
    cookTime: row.cookTime ?? undefined,
    totalTime: row.totalTime ?? undefined,
    ingredients: parseJsonArray(row.ingredients),
    directions: parseJsonArray(row.directions),
    nutrition: parseJsonObject(row.nutrition),
    sourceUrl: row.sourceUrl ?? undefined,
    imageUrl: row.imageUrl ?? undefined,
    notes: row.notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

export function linesToList(value: string) {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

export function listToLines(items: string[]) {
  return items.join("\n");
}

export function recipeInputFromParsed(
  recipe: ParsedRecipe & { notes?: string | null },
) {
  return {
    title: recipe.title,
    description: recipe.description ?? "",
    servings: recipe.servings ?? "",
    prepTime: recipe.prepTime ?? "",
    cookTime: recipe.cookTime ?? "",
    totalTime: recipe.totalTime ?? "",
    ingredients: listToLines(recipe.ingredients),
    directions: listToLines(recipe.directions),
    nutrition: recipe.nutrition
      ? Object.entries(recipe.nutrition)
          .map(([label, value]) => `${label}: ${value}`)
          .join("\n")
      : "",
    sourceUrl: recipe.sourceUrl ?? "",
    imageUrl: recipe.imageUrl ?? "",
    notes: recipe.notes ?? "",
  };
}
