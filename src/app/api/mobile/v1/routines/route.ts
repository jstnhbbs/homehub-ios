import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { routineSteps, routines, profiles } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const routineRows = await db
      .select()
      .from(routines)
      .where(eq(routines.householdId, household.id))
      .orderBy(asc(routines.sortOrder));

    const steps = await db
      .select()
      .from(routineSteps)
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(eq(routines.householdId, household.id))
      .orderBy(asc(routineSteps.sortOrder));

    const stepsByRoutine = new Map<string, typeof routineSteps.$inferSelect[]>();
    for (const row of steps) {
      const routineId = row.routine_steps.routineId;
      const list = stepsByRoutine.get(routineId) ?? [];
      list.push(row.routine_steps);
      stepsByRoutine.set(routineId, list);
    }

    return mobileJson(
      routineRows.map((routine) => ({
        ...routine,
        steps: stepsByRoutine.get(routine.id) ?? [],
      })),
    );
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        name: shortText,
        period: z.enum(["morning", "afternoon", "evening"]),
        profileId: z.string().uuid().optional(),
        days: z.string().default("0,1,2,3,4,5,6"),
        steps: z.array(shortText).min(1).max(30),
      })
      .parse(await parseJsonBody(request));

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

    const routineId = randomUUID();
    await db.transaction(async (tx) => {
      await tx.insert(routines).values({
        id: routineId,
        householdId: household.id,
        name: input.name,
        period: input.period,
        profileId: input.profileId ?? null,
        days: input.days,
      });
      await tx.insert(routineSteps).values(
        input.steps.map((label, index) => ({
          id: randomUUID(),
          routineId,
          label,
          sortOrder: index,
        })),
      );
    });

    const created = await db
      .select()
      .from(routines)
      .where(eq(routines.id, routineId))
      .limit(1);
    const createdSteps = await db
      .select()
      .from(routineSteps)
      .where(eq(routineSteps.routineId, routineId))
      .orderBy(asc(routineSteps.sortOrder));

    return mobileJson({ ...created[0], steps: createdSteps }, 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
