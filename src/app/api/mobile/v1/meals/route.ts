import { randomUUID } from "node:crypto";
import { and, eq, gte, lte } from "drizzle-orm";
import { addDays, format, parseISO } from "date-fns";
import { z } from "zod";
import { db } from "@/db/client";
import { meals, recipes } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function GET(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const weekStart = z
      .string()
      .date()
      .parse(new URL(request.url).searchParams.get("weekStart"));
    const weekEnd = format(addDays(parseISO(weekStart), 6), "yyyy-MM-dd");

    const rows = await db
      .select()
      .from(meals)
      .where(
        and(
          eq(meals.householdId, household.id),
          gte(meals.localDate, weekStart),
          lte(meals.localDate, weekEnd),
        ),
      );

    return mobileJson(rows);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        localDate: z.string().date(),
        slot: z.enum(["breakfast", "lunch", "dinner", "snack"]),
        title: z.string().max(600),
        recipeId: z.string().uuid().optional(),
        notes: z.string().max(600).optional(),
      })
      .parse(await parseJsonBody(request));

    const normalizedTitle = input.title
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .join("\n");

    if (!normalizedTitle) {
      await db
        .delete(meals)
        .where(
          and(
            eq(meals.householdId, household.id),
            eq(meals.localDate, input.localDate),
            eq(meals.slot, input.slot),
          ),
        );
      return mobileJson({ ok: true });
    }

    let recipeId = input.recipeId ?? null;
    let title = normalizedTitle;
    if (recipeId) {
      const recipe = await db
        .select({ id: recipes.id, title: recipes.title })
        .from(recipes)
        .where(
          and(eq(recipes.id, recipeId), eq(recipes.householdId, household.id)),
        )
        .limit(1);
      if (!recipe[0]) {
        recipeId = null;
      } else {
        title = recipe[0].title;
      }
    }

    const id = randomUUID();
    await db
      .insert(meals)
      .values({
        id,
        householdId: household.id,
        localDate: input.localDate,
        slot: input.slot,
        title,
        recipeId,
        notes: input.notes ?? null,
      })
      .onConflictDoUpdate({
        target: [meals.householdId, meals.localDate, meals.slot],
        set: { title, recipeId, notes: input.notes ?? null, updatedAt: new Date() },
      });

    const saved = await db
      .select()
      .from(meals)
      .where(
        and(
          eq(meals.householdId, household.id),
          eq(meals.localDate, input.localDate),
          eq(meals.slot, input.slot),
        ),
      )
      .limit(1);

    return mobileJson(saved[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}
