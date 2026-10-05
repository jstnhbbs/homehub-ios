import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { applyCompletion } from "@/lib/completion-state";
import { db } from "@/db/client";
import {
  routineCompletions,
  routineSteps,
  routines,
} from "@/db/schema";
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
        stepId: z.string().uuid(),
        localDate: z.string().date(),
        // The state the app wants. Left out by older apps, which means "flip it".
        completed: z.boolean().optional(),
      })
      .parse(await parseJsonBody(request));

    const step = await db
      .select({ id: routineSteps.id })
      .from(routineSteps)
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(
        and(
          eq(routineSteps.id, input.stepId),
          eq(routines.householdId, household.id),
        ),
      )
      .limit(1);
    if (!step[0]) throw new Error("Routine step not found.");

    const match = and(
      eq(routineCompletions.stepId, input.stepId),
      eq(routineCompletions.localDate, input.localDate),
    );
    const completed = await applyCompletion(input.completed, {
      isDone: async () =>
        Boolean(
          (
            await db
              .select({ stepId: routineCompletions.stepId })
              .from(routineCompletions)
              .where(match)
              .limit(1)
          )[0],
        ),
      // Already done by someone else: leave that first completion (and who did it) as it is.
      mark: async () => {
        await db
          .insert(routineCompletions)
          .values({
            stepId: input.stepId,
            localDate: input.localDate,
            completedBy: user.id,
          })
          .onConflictDoNothing();
      },
      unmark: async () => {
        await db.delete(routineCompletions).where(match);
      },
    });

    return mobileJson({ ok: true, completed });
  } catch (error) {
    return handleMobileError(error);
  }
}
