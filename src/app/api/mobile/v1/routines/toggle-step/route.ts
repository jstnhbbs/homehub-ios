import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import {
  routineCompletions,
  routineSteps,
  routines,
} from "@/db/schema";
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
        stepId: z.string().uuid(),
        localDate: z.string().date(),
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

    const existing = await db
      .select({ stepId: routineCompletions.stepId })
      .from(routineCompletions)
      .where(
        and(
          eq(routineCompletions.stepId, input.stepId),
          eq(routineCompletions.localDate, input.localDate),
        ),
      )
      .limit(1);

    if (existing[0]) {
      await db
        .delete(routineCompletions)
        .where(
          and(
            eq(routineCompletions.stepId, input.stepId),
            eq(routineCompletions.localDate, input.localDate),
          ),
        );
    } else {
      await db
        .insert(routineCompletions)
        .values({ stepId: input.stepId, localDate: input.localDate })
        .onConflictDoNothing();
    }

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
