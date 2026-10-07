import { and, eq, or } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { meals } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const slotSchema = z.object({
  localDate: z.string().date(),
  slot: z.enum(["breakfast", "lunch", "dinner", "snack"]),
});

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const { source, target } = z
      .object({ source: slotSchema, target: slotSchema })
      .parse(await parseJsonBody(request));
    if (source.localDate === target.localDate && source.slot === target.slot) {
      throw new Error("Choose a different meal slot.");
    }

    // Read and move both slots in one transaction: either the whole swap commits or neither does.
    const moved = await db.transaction(async (tx) => {
      const match = and(
        eq(meals.householdId, household.id),
        or(
          and(eq(meals.localDate, source.localDate), eq(meals.slot, source.slot)),
          and(eq(meals.localDate, target.localDate), eq(meals.slot, target.slot)),
        ),
      );
      const rows = await tx.select().from(meals).where(match);
      const from = rows.find(
        (row) => row.localDate === source.localDate && row.slot === source.slot,
      );
      const to = rows.find(
        (row) => row.localDate === target.localDate && row.slot === target.slot,
      );
      if (!from) throw new Error("The meal has changed. Refresh the plan and try again.");

      await tx.delete(meals).where(match);
      const updatedAt = new Date();
      const replacements = [
        { ...from, ...target, updatedAt },
        ...(to ? [{ ...to, ...source, updatedAt }] : []),
      ];
      return tx.insert(meals).values(replacements).returning();
    });
    return mobileJson({ meals: moved });
  } catch (error) {
    return handleMobileError(error);
  }
}
