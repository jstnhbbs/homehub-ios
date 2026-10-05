import { randomUUID } from "node:crypto";
import { and, eq, inArray } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { recipes } from "@/db/schema";
import { RateLimitedError } from "@/lib/errors";
import {
  croutonRecipeSchema,
  mapCroutonRecipe,
  type ImportedRecipe,
} from "@/lib/recipes/crouton";
import { serializeRecipeFields } from "@/lib/recipes/store";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

/** The app sends recipes in small batches, text only; the photos are uploaded afterwards. */
const MAX_PER_REQUEST = 25;

const bodySchema = z.object({
  recipes: z.array(z.unknown()).min(1).max(MAX_PER_REQUEST),
});

type Result = {
  index: number;
  title: string;
  status: "created" | "duplicate" | "failed";
  /** The recipe's id here, for "created" and "duplicate". */
  id?: string;
  error?: string;
};

function describeProblem(error: z.ZodError) {
  const issue = error.issues[0];
  const where = issue?.path.join(".");
  return where ? `${where}: ${issue.message}` : (issue?.message ?? "This file could not be read.");
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const allowed = await checkRateLimit("crouton-import", household.id, {
      limit: 60,
      windowMs: 60 * 60 * 1000,
    });
    if (!allowed) {
      throw new RateLimitedError("Too many import requests. Try again in a little while.");
    }

    const { recipes: items } = bodySchema.parse(await parseJsonBody(request));

    // Each recipe stands alone: one that can't be read is reported, the rest still go in.
    const results: Result[] = [];
    const ready: Array<{ index: number; mapped: ImportedRecipe }> = [];
    items.forEach((raw, index) => {
      const parsed = croutonRecipeSchema.safeParse(raw);
      if (!parsed.success) {
        const title =
          typeof (raw as { name?: unknown } | null)?.name === "string"
            ? String((raw as { name: string }).name).slice(0, 200)
            : "Unnamed recipe";
        results.push({ index, title, status: "failed", error: describeProblem(parsed.error) });
        return;
      }
      ready.push({ index, mapped: mapCroutonRecipe(parsed.data) });
    });

    // Recipes already imported from this export, found by the id Crouton gave them.
    const keys = ready.map((item) => item.mapped.importKey);
    const existing = keys.length
      ? await db
          .select({ id: recipes.id, importKey: recipes.importKey })
          .from(recipes)
          .where(and(eq(recipes.householdId, household.id), inArray(recipes.importKey, keys)))
      : [];
    const known = new Map(existing.map((row) => [row.importKey, row.id]));

    for (const { index, mapped } of ready) {
      const already = known.get(mapped.importKey);
      if (already) {
        results.push({ index, title: mapped.title, status: "duplicate", id: already });
        continue;
      }

      const id = randomUUID();
      // The unique index settles a race (two requests importing the same file at once): the
      // loser inserts nothing and is reported as a duplicate.
      const inserted = await db
        .insert(recipes)
        .values({
          id,
          householdId: household.id,
          title: mapped.title,
          description: null,
          servings: mapped.servings ?? null,
          prepTime: mapped.prepTime ?? null,
          cookTime: mapped.cookTime ?? null,
          totalTime: mapped.totalTime ?? null,
          sourceUrl: mapped.sourceUrl ?? null,
          imageUrl: null,
          notes: mapped.notes ?? null,
          importKey: mapped.importKey,
          ...serializeRecipeFields(mapped),
        })
        .onConflictDoNothing()
        .returning({ id: recipes.id });

      if (inserted[0]) {
        known.set(mapped.importKey, id);
        results.push({ index, title: mapped.title, status: "created", id });
      } else {
        results.push({ index, title: mapped.title, status: "duplicate" });
      }
    }

    results.sort((a, b) => a.index - b.index);
    return mobileJson({
      results,
      created: results.filter((result) => result.status === "created").length,
      duplicates: results.filter((result) => result.status === "duplicate").length,
      failed: results.filter((result) => result.status === "failed").length,
    });
  } catch (error) {
    return handleMobileError(error);
  }
}
