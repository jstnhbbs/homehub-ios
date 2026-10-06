import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { applyCompletion } from "@/lib/completion-state";
import { db } from "@/db/client";
import { choreCompletions, chores } from "@/db/schema";
import { chorePeriodKeyPattern } from "@/lib/chores";
import {
  handleMobileError,
  requireMobileContext,
  mobileJson,
  parseJsonBody,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const { user, household } = await requireMobileContext();
    const input = z
      .object({
        choreId: z.string().uuid(),
        periodKey: z.string().min(1).max(20),
        // The state the app wants. Left out by older apps, which means "flip it".
        completed: z.boolean().optional(),
      })
      .parse(await parseJsonBody(request));

    const chore = await db
      .select({
        id: chores.id,
        repeatUnit: chores.repeatUnit,
        repeatInterval: chores.repeatInterval,
      })
      .from(chores)
      .where(
        and(eq(chores.id, input.choreId), eq(chores.householdId, household.id)),
      )
      .limit(1);
    if (!chore[0]) throw new Error("Chore not found.");
    // A one-off is checked off once, a weekly chore by week and everything else by day. Anything
    // else would be a completion for a period that doesn't exist, which nothing would read back.
    if (!chorePeriodKeyPattern(chore[0]).test(input.periodKey)) throw new Error("That is not a valid period for this chore.");

    const match = and(
      eq(choreCompletions.choreId, input.choreId),
      eq(choreCompletions.periodKey, input.periodKey),
    );
    const completed = await applyCompletion(input.completed, {
      isDone: async () =>
        Boolean(
          (
            await db
              .select({ choreId: choreCompletions.choreId })
              .from(choreCompletions)
              .where(match)
              .limit(1)
          )[0],
        ),
      // Already done by someone else: leave that first completion (and who did it) as it is.
      mark: async () => {
        await db
          .insert(choreCompletions)
          .values({
            choreId: input.choreId,
            periodKey: input.periodKey,
            completedBy: user.id,
          })
          .onConflictDoNothing();
      },
      unmark: async () => {
        await db.delete(choreCompletions).where(match);
      },
    });

    return mobileJson({ ok: true, completed });
  } catch (error) {
    return handleMobileError(error);
  }
}
