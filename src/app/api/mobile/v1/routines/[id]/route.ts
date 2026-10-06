import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { profiles, routineSteps, routines } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";
import { normalizeRoutineDays, pairRoutineSteps } from "@/lib/routines";

const shortText = z.string().trim().min(1).max(120);

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z
      .string()
      .uuid()
      .parse((await context.params).id);
    const input = z
      .object({
        name: shortText,
        period: z.enum(["morning", "afternoon", "evening"]),
        profileId: z.string().uuid().optional(),
        // Left out by apps that predate day choices, which means "leave the days alone".
        days: z.string().optional(),
        steps: z.array(shortText).min(1).max(30),
      })
      .parse(await parseJsonBody(request));

    const routine = await db
      .select({ id: routines.id })
      .from(routines)
      .where(and(eq(routines.id, id), eq(routines.householdId, household.id)))
      .limit(1);
    if (!routine[0]) throw new Error("Routine not found.");

    if (input.profileId) {
      const profile = await db
        .select({ id: profiles.id })
        .from(profiles)
        .where(
          and(
            eq(profiles.id, input.profileId),
            eq(profiles.householdId, household.id)
          )
        )
        .limit(1);
      if (!profile[0]) throw new Error("Invalid family profile.");
    }

    await db.transaction(async (tx) => {
      await tx
        .update(routines)
        .set({
          name: input.name,
          profileId: input.profileId ?? null,
          period: input.period,
          ...(input.days === undefined
            ? {}
            : { days: normalizeRoutineDays(input.days) }),
          updatedAt: new Date(),
        })
        .where(eq(routines.id, id));

      const existingSteps = await tx
        .select({ id: routineSteps.id, label: routineSteps.label })
        .from(routineSteps)
        .where(eq(routineSteps.routineId, id))
        .orderBy(asc(routineSteps.sortOrder));

      // A step keeps its row, and so what has been checked off, when it is only moved.
      const { pairs, removed } = pairRoutineSteps(existingSteps, input.steps);
      for (const [index, pair] of pairs.entries()) {
        if (pair.id) {
          await tx
            .update(routineSteps)
            .set({ label: pair.label, sortOrder: index })
            .where(eq(routineSteps.id, pair.id));
        } else {
          await tx.insert(routineSteps).values({
            id: randomUUID(),
            routineId: id,
            label: pair.label,
            sortOrder: index,
            createdAt: new Date(),
          });
        }
      }

      for (const removedId of removed) {
        await tx.delete(routineSteps).where(eq(routineSteps.id, removedId));
      }
    });

    const updated = await db
      .select()
      .from(routines)
      .where(eq(routines.id, id))
      .limit(1);
    const steps = await db
      .select()
      .from(routineSteps)
      .where(eq(routineSteps.routineId, id))
      .orderBy(asc(routineSteps.sortOrder));

    return mobileJson({ ...updated[0], steps });
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z
      .string()
      .uuid()
      .parse((await context.params).id);
    const deleted = await db
      .delete(routines)
      .where(and(eq(routines.id, id), eq(routines.householdId, household.id)))
      .returning({ id: routines.id });
    if (!deleted[0]) throw new Error("Routine not found.");
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
