import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { RateLimitedError } from "@/lib/errors";
import {
  deleteStoredRecipeImage,
  RECIPE_IMAGE_MAX_BYTES,
  storeRecipeImage,
} from "@/lib/recipes/image";
import { recipeFromRow } from "@/lib/recipes/store";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ id: string }> };

/** Sets a recipe's photo from an uploaded file. Used by the Crouton import, which sends one per recipe. */
export async function POST(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);

    // Importing a whole export sends a photo per recipe, so this has to allow a few hundred.
    const allowed = await checkRateLimit("recipe-image", household.id, {
      limit: 600,
      windowMs: 60 * 60 * 1000,
    });
    if (!allowed) throw new RateLimitedError("Too many photo uploads. Try again in a little while.");

    const existing = await db
      .select()
      .from(recipes)
      .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
      .limit(1);
    if (!existing[0]) throw new Error("Recipe not found.");

    const file = (await request.formData()).get("file");
    if (!(file instanceof File)) throw new Error("Photo file is required.");
    if (file.size > RECIPE_IMAGE_MAX_BYTES) throw new Error("Choose an image smaller than 5 MB.");

    const url = await storeRecipeImage({
      householdId: household.id,
      recipeId: id,
      data: Buffer.from(await file.arrayBuffer()),
    });

    const updated = await db
      .update(recipes)
      .set({ imageUrl: url, updatedAt: new Date() })
      .where(and(eq(recipes.id, id), eq(recipes.householdId, household.id)))
      .returning();
    if (!updated[0]) throw new Error("Recipe not found.");

    // The photo it replaces, if that was one we stored. Nothing is deleted from other websites.
    if (existing[0].imageUrl && existing[0].imageUrl !== url) {
      await deleteStoredRecipeImage(existing[0].imageUrl, household.id);
    }
    return mobileJson(recipeFromRow(updated[0]));
  } catch (error) {
    return handleMobileError(error);
  }
}
