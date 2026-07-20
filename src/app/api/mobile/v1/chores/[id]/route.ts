import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { chores, profiles } from "@/db/schema";
import { choreDaysForCadence } from "@/lib/chores";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

const choreInputSchema = z.object({
  title: shortText,
  profileId: z.string().uuid().optional(),
  cadence: z.enum(["daily", "weekly"]),
  weekDay: z.enum(["0", "1", "2", "3", "4", "5", "6"]).optional(),
});

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const input = choreInputSchema.parse(await parseJsonBody(request));

    const chore = await db
      .select({ id: chores.id })
      .from(chores)
      .where(and(eq(chores.id, id), eq(chores.householdId, household.id)))
      .limit(1);
    if (!chore[0]) throw new Error("Chore not found.");

    if (input.profileId) {
      const profile = await db
        .select({ id: profiles.id })
        .from(profiles)
        .where(
          and(
            eq(profiles.id, input.profileId),
            eq(profiles.householdId, household.id),
          ),
        )
        .limit(1);
      if (!profile[0]) throw new Error("Invalid family profile.");
    }

    const updated = await db
      .update(chores)
      .set({
        title: input.title,
        profileId: input.profileId ?? null,
        cadence: input.cadence,
        days: choreDaysForCadence(input.cadence, input.weekDay),
        updatedAt: new Date(),
      })
      .where(eq(chores.id, id))
      .returning();

    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const deleted = await db
      .delete(chores)
      .where(and(eq(chores.id, id), eq(chores.householdId, household.id)))
      .returning({ id: chores.id });
    if (!deleted[0]) throw new Error("Chore not found.");
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
