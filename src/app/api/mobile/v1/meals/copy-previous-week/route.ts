import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { addDays, format, parseISO, subWeeks } from "date-fns";
import { z } from "zod";
import { db } from "@/db/client";
import { meals } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const { weekStart } = z
      .object({ weekStart: z.string().date() })
      .parse(await parseJsonBody(request));
    const start = parseISO(weekStart);
    const priorStart = subWeeks(start, 1);
    const priorMeals = await db
      .select()
      .from(meals)
      .where(eq(meals.householdId, household.id));
    const sourceDates = new Map(
      Array.from({ length: 7 }, (_, index) => [
        format(addDays(priorStart, index), "yyyy-MM-dd"),
        format(addDays(start, index), "yyyy-MM-dd"),
      ]),
    );
    for (const meal of priorMeals) {
      if (meal.slot === "snack") continue;
      const targetDate = sourceDates.get(meal.localDate);
      if (!targetDate) continue;
      await db
        .insert(meals)
        .values({
          id: randomUUID(),
          householdId: household.id,
          localDate: targetDate,
          slot: meal.slot,
          title: meal.title,
          recipeId: meal.recipeId,
          notes: meal.notes,
        })
        .onConflictDoUpdate({
          target: [meals.householdId, meals.localDate, meals.slot],
          set: {
            title: meal.title,
            recipeId: meal.recipeId,
            notes: meal.notes,
            updatedAt: new Date(),
          },
        });
    }
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
