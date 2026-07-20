import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { snackCompletions } from "@/db/schema";
import { parseSnackOptions } from "@/lib/meals/snacks";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

export async function POST(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const input = z
      .object({
        localDate: z.string().date(),
        snackLabel: shortText,
      })
      .parse(await parseJsonBody(request));

    const allowed = parseSnackOptions(household.snackOptions);
    if (!allowed.includes(input.snackLabel)) {
      throw new Error("Snack not found.");
    }

    const existing = await db
      .select({ snackLabel: snackCompletions.snackLabel })
      .from(snackCompletions)
      .where(
        and(
          eq(snackCompletions.householdId, household.id),
          eq(snackCompletions.localDate, input.localDate),
          eq(snackCompletions.snackLabel, input.snackLabel),
        ),
      )
      .limit(1);

    if (existing[0]) {
      await db
        .delete(snackCompletions)
        .where(
          and(
            eq(snackCompletions.householdId, household.id),
            eq(snackCompletions.localDate, input.localDate),
            eq(snackCompletions.snackLabel, input.snackLabel),
          ),
        );
    } else {
      await db
        .insert(snackCompletions)
        .values({
          householdId: household.id,
          localDate: input.localDate,
          snackLabel: input.snackLabel,
        })
        .onConflictDoNothing();
    }

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
