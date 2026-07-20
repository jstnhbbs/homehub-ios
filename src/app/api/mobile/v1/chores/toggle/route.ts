import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { choreCompletions, chores } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const input = z
      .object({
        choreId: z.string().uuid(),
        periodKey: z.string().min(1),
      })
      .parse(await parseJsonBody(request));

    const chore = await db
      .select({ id: chores.id })
      .from(chores)
      .where(
        and(eq(chores.id, input.choreId), eq(chores.householdId, household.id)),
      )
      .limit(1);
    if (!chore[0]) throw new Error("Chore not found.");

    const existing = await db
      .select({ choreId: choreCompletions.choreId })
      .from(choreCompletions)
      .where(
        and(
          eq(choreCompletions.choreId, input.choreId),
          eq(choreCompletions.periodKey, input.periodKey),
        ),
      )
      .limit(1);

    if (existing[0]) {
      await db
        .delete(choreCompletions)
        .where(
          and(
            eq(choreCompletions.choreId, input.choreId),
            eq(choreCompletions.periodKey, input.periodKey),
          ),
        );
    } else {
      await db
        .insert(choreCompletions)
        .values({ choreId: input.choreId, periodKey: input.periodKey })
        .onConflictDoNothing();
    }

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
