import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { recipeFromRow, serializeRecipeFields } from "@/lib/recipes/store";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(200);
const bodyText = z.string().trim().max(4000);

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
  sourceUrl: z.string().url().optional(),
  imageUrl: z.string().url().optional(),
  notes: bodyText.optional(),
});

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const row = await db
      .select()
      .from(recipes)
      .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
      .limit(1);
    if (!row[0]) throw new Error("Recipe not found.");
    return mobileJson(recipeFromRow(row[0]));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const input = recipeInputSchema.parse(await parseJsonBody(request));
    const updated = await db
      .update(recipes)
      .set({
        ...input,
        description: input.description ?? null,
        servings: input.servings ?? null,
        prepTime: input.prepTime ?? null,
        cookTime: input.cookTime ?? null,
        totalTime: input.totalTime ?? null,
        sourceUrl: input.sourceUrl ?? null,
        imageUrl: input.imageUrl ?? null,
        notes: input.notes ?? null,
        ...serializeRecipeFields(input),
        updatedAt: new Date(),
      })
      .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
      .returning();
    if (!updated[0]) throw new Error("Recipe not found.");
    return mobileJson(recipeFromRow(updated[0]));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const deleted = await db
      .delete(recipes)
      .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
      .returning({ id: recipes.id });
    if (!deleted[0]) throw new Error("Recipe not found.");
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
