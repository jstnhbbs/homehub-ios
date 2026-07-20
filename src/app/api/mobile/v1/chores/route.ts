import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { choreCompletions, chores, profiles } from "@/db/schema";
import { choreDaysForCadence, isChoreDueOnDate } from "@/lib/chores";
import { localDateIn, weekKey } from "@/lib/dates";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

const choreInputSchema = z.object({
  title: shortText,
  profileId: z.string().uuid().optional(),
  cadence: z.enum(["daily", "weekly"]),
  weekDay: z.enum(["0", "1", "2", "3", "4", "5", "6"]).optional(),
});

export async function GET(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const params = new URL(request.url).searchParams;
    const scope = params.get("scope") ?? "due";
    const localDate =
      params.get("localDate") ?? localDateIn(household.timezone);
    const weeklyKey = weekKey(new Date(`${localDate}T12:00:00`));

    const choreRows = await db
      .select()
      .from(chores)
      .where(eq(chores.householdId, household.id))
      .orderBy(asc(chores.sortOrder));

    const choreDone = await db
      .select({
        choreId: choreCompletions.choreId,
        periodKey: choreCompletions.periodKey,
      })
      .from(choreCompletions)
      .innerJoin(chores, eq(choreCompletions.choreId, chores.id))
      .where(eq(chores.householdId, household.id));

    const rows =
      scope === "all"
        ? choreRows
        : choreRows.filter((chore) =>
            isChoreDueOnDate(
              chore.cadence,
              chore.days,
              localDate,
              household.timezone,
            ),
          );

    return mobileJson(
      rows.map((chore) => {
        const periodKey = chore.cadence === "weekly" ? weeklyKey : localDate;
        const completed = choreDone.some(
          (item) => item.choreId === chore.id && item.periodKey === periodKey,
        );
        const dueToday = isChoreDueOnDate(
          chore.cadence,
          chore.days,
          localDate,
          household.timezone,
        );
        return {
          id: chore.id,
          title: chore.title,
          profileId: chore.profileId,
          cadence: chore.cadence,
          days: chore.days,
          sortOrder: chore.sortOrder,
          periodKey,
          completed,
          dueToday,
        };
      }),
    );
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = choreInputSchema.parse(await parseJsonBody(request));

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

    const id = randomUUID();
    await db.insert(chores).values({
      id,
      householdId: household.id,
      title: input.title,
      profileId: input.profileId ?? null,
      cadence: input.cadence,
      days: choreDaysForCadence(input.cadence, input.weekDay),
    });

    const created = await db
      .select()
      .from(chores)
      .where(eq(chores.id, id))
      .limit(1);

    return mobileJson(created[0], 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
