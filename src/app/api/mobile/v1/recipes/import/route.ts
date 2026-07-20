import { randomUUID } from "node:crypto";
import { z } from "zod";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { importRecipeFromUrl } from "@/lib/recipes/import";
import { recipeFromRow, serializeRecipeFields } from "@/lib/recipes/store";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";
import { eq } from "drizzle-orm";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const allowed = await checkRateLimit("recipe-import", household.id, {
      limit: 10,
      windowMs: 60 * 60 * 1000,
    });
    if (!allowed) {
      throw new Error("Too many recipe imports. Try again later.");
    }
    const { url: sourceUrl } = z
      .object({ url: z.string().url() })
      .parse(await parseJsonBody(request));
    const parsed = await importRecipeFromUrl(sourceUrl);
    const id = randomUUID();
    await db.insert(recipes).values({
      id,
      householdId: household.id,
      title: parsed.title,
      description: parsed.description ?? null,
      servings: parsed.servings ?? null,
      prepTime: parsed.prepTime ?? null,
      cookTime: parsed.cookTime ?? null,
      totalTime: parsed.totalTime ?? null,
      sourceUrl: parsed.sourceUrl ?? sourceUrl,
      imageUrl: parsed.imageUrl ?? null,
      ...serializeRecipeFields(parsed),
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
