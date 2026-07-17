"use server";

import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { importRecipeFromUrl } from "@/lib/recipes/import";
import {
  linesToList,
  serializeRecipeFields,
} from "@/lib/recipes/store";
import { requireParentHousehold } from "@/lib/household";
import { checkRateLimit } from "@/lib/rate-limit";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

const shortText = z.string().trim().min(1).max(200);
const bodyText = z.string().trim().max(4000);

function parseNutritionInput(value: string) {
  if (!value) return undefined;
  const nutrition: Record<string, string> = {};
  for (const line of linesToList(value)) {
    const split = line.split(":");
    const label = split.shift()?.trim();
    const amount = split.join(":").trim();
    if (label && amount) nutrition[label] = amount;
  }
  return Object.keys(nutrition).length ? nutrition : undefined;
}

const recipeInputSchema = z.object({
  title: shortText,
  description: bodyText.optional(),
  servings: z.string().trim().max(120).optional(),
  prepTime: z.string().trim().max(80).optional(),
  cookTime: z.string().trim().max(80).optional(),
  totalTime: z.string().trim().max(80).optional(),
  ingredients: z.array(z.string().trim().min(1).max(300)).min(1).max(80),
  directions: z.array(z.string().trim().min(1).max(1000)).min(1).max(80),
  nutrition: z.record(z.string(), z.string()).optional(),
  sourceUrl: z.string().url().optional().or(z.literal("")),
  imageUrl: z.string().url().optional().or(z.literal("")),
  notes: bodyText.optional(),
});

function parseRecipeForm(formData: FormData) {
  return recipeInputSchema.parse({
    title: text(formData, "title"),
    description: text(formData, "description") || undefined,
    servings: text(formData, "servings") || undefined,
    prepTime: text(formData, "prepTime") || undefined,
    cookTime: text(formData, "cookTime") || undefined,
    totalTime: text(formData, "totalTime") || undefined,
    ingredients: linesToList(text(formData, "ingredients")),
    directions: linesToList(text(formData, "directions")),
    nutrition: parseNutritionInput(text(formData, "nutrition")),
    sourceUrl: text(formData, "sourceUrl") || undefined,
    imageUrl: text(formData, "imageUrl") || undefined,
    notes: text(formData, "notes") || undefined,
  });
}

export async function addRecipe(formData: FormData) {
  const household = await requireParentHousehold();
  const input = parseRecipeForm(formData);
  const id = randomUUID();
  await db.insert(recipes).values({
    id,
    householdId: household.id,
    ...input,
    ...serializeRecipeFields(input),
  });
  revalidatePath("/", "layout");
  redirect(`/recipes/${id}`);
}

export async function importRecipe(formData: FormData) {
  const household = await requireParentHousehold();
  const allowed = await checkRateLimit("recipe-import", household.id, {
    limit: 20,
    windowMs: 60 * 60 * 1000,
  });
  if (!allowed) {
    throw new Error("Too many recipe imports. Try again later.");
  }

  const url = z.string().url().parse(text(formData, "url"));
  const imported = await importRecipeFromUrl(url);
  const id = randomUUID();
  await db.insert(recipes).values({
    id,
    householdId: household.id,
    title: imported.title,
    description: imported.description,
    servings: imported.servings,
    prepTime: imported.prepTime,
    cookTime: imported.cookTime,
    totalTime: imported.totalTime,
    sourceUrl: imported.sourceUrl,
    imageUrl: imported.imageUrl,
    ...serializeRecipeFields(imported),
  });
  revalidatePath("/", "layout");
  redirect(`/recipes/${id}`);
}

export async function updateRecipe(recipeId: string, formData: FormData) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(recipeId);
  const input = parseRecipeForm(formData);
  const updated = await db
    .update(recipes)
    .set({
      ...input,
      ...serializeRecipeFields(input),
      updatedAt: new Date(),
    })
    .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
    .returning({ id: recipes.id });
  if (!updated[0]) throw new Error("Recipe not found.");
  revalidatePath("/", "layout");
  redirect(`/recipes/${id}`);
}

export async function deleteRecipe(recipeId: string) {
  const household = await requireParentHousehold();
  const id = z.string().uuid().parse(recipeId);
  const deleted = await db
    .delete(recipes)
    .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
    .returning({ id: recipes.id });
  if (!deleted[0]) throw new Error("Recipe not found.");
  revalidatePath("/", "layout");
  redirect("/recipes");
}
