import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
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

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const rows = await db
      .select()
      .from(recipes)
      .where(eq(recipes.householdId, household.id))
      .orderBy(asc(recipes.title));
    return mobileJson(rows.map(recipeFromRow));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = recipeInputSchema.parse(await parseJsonBody(request));
    const id = randomUUID();
    await db.insert(recipes).values({
      id,
      householdId: household.id,
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
    });
    const row = await db
      .select()
      .from(recipes)
      .where(eq(recipes.id, id))
      .limit(1);
    return mobileJson(recipeFromRow(row[0]!), 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
