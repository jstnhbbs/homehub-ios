import { randomUUID } from "node:crypto";
import { and, asc, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { choreCompletions, chores, profiles, users } from "@/db/schema";
import { choreInputSchema, choreScheduleColumns } from "@/lib/chore-input";
import { choreState } from "@/lib/chores";
import { localDateIn } from "@/lib/dates";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function GET(request: Request) {
  try {
    const household = await requireMobileHousehold();
    const params = new URL(request.url).searchParams;
    const scope = params.get("scope") ?? "due";
    const localDate =
      params.get("localDate") ?? localDateIn(household.timezone);

    const choreRows = await db
      .select()
      .from(chores)
      .where(eq(chores.householdId, household.id))
      .orderBy(asc(chores.sortOrder));

    const choreDone = await db
      .select({
        choreId: choreCompletions.choreId,
        periodKey: choreCompletions.periodKey,
        completedAt: choreCompletions.completedAt,
        completedByName: users.name,
      })
      .from(choreCompletions)
      .innerJoin(chores, eq(choreCompletions.choreId, chores.id))
      .leftJoin(users, eq(choreCompletions.completedBy, users.id))
      .where(eq(chores.householdId, household.id));

    const now = new Date();
    const items = choreRows.map((chore) => {
      const completionFor = (periodKey: string) =>
        choreDone.find(
          (item) => item.choreId === chore.id && item.periodKey === periodKey,
        );
      const state = choreState(chore, {
        localDate,
        timezone: household.timezone,
        now,
        completionFor,
      });
      return { chore, done: completionFor(state.periodKey), state };
    });

    return mobileJson(
      items
        .filter(({ state }) => scope === "all" || state.dueToday)
        .map(({ chore, done, state }) => ({
          id: chore.id,
          title: chore.title,
          profileId: chore.profileId,
          cadence: chore.cadence,
          days: chore.days,
          sortOrder: chore.sortOrder,
          dueDate: chore.dueDate,
          dueTime: chore.dueTime,
          repeatUnit: chore.repeatUnit,
          repeatInterval: chore.repeatInterval,
          periodKey: state.periodKey,
          completed: state.completed,
          completedAt: done?.completedAt ?? null,
          completedByName: done?.completedByName ?? null,
          dueToday: state.dueToday,
          overdue: state.overdue,
          nextDueDate: state.nextDueDate,
        })),
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
      ...choreScheduleColumns(input),
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
