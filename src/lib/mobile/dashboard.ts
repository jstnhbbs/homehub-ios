import { and, asc, desc, eq } from "drizzle-orm";
import { fromZonedTime } from "date-fns-tz";
import { db } from "@/db/client";
import {
  choreCompletions,
  chores,
  householdNotes,
  meals,
  profiles,
  routineCompletions,
  routines,
  routineSteps,
  snackCompletions,
  familyBirthdays,
  groceryItems,
  users,
} from "@/db/schema";
import { birthdayEventsInRange } from "@/lib/birthdays";
import { listHouseholdBirthdays } from "@/lib/family-birthdays";
import { isChoreDueOnDate } from "@/lib/chores";
import { localDateIn, weekKey } from "@/lib/dates";
import { parseSnackOptions } from "@/lib/meals/snacks";
import { fetchNapsForDate, serializeNap } from "@/lib/naps/store";
import type { getCurrentHousehold } from "@/lib/household";
import { getUserHubModules } from "@/lib/hub-modules-store";
import { loadRoutineStreaks } from "@/lib/streak-store";
import { serializeHousehold } from "@/lib/mobile/http";

type Household = NonNullable<Awaited<ReturnType<typeof getCurrentHousehold>>>;

export async function buildDashboardPayload(
  household: Household,
  userId: string,
) {
  const localDate = localDateIn(household.timezone);
  const dayStart = fromZonedTime(`${localDate}T00:00:00`, household.timezone);
  const weeklyKey = weekKey(dayStart);

  const [
    familyProfiles,
    routineRows,
    routineDone,
    choreRows,
    choreDone,
    todayMeals,
    snackDone,
    todayNaps,
    groceryRows,
    noteRows,
    familyBirthdayRows,
    routineStreaks,
  ] = await Promise.all([
    db
      .select()
      .from(profiles)
      .where(eq(profiles.householdId, household.id))
      .orderBy(asc(profiles.sortOrder)),
    db
      .select({
        id: routineSteps.id,
        label: routineSteps.label,
        routineName: routines.name,
        period: routines.period,
        profileId: routines.profileId,
      })
      .from(routineSteps)
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .where(eq(routines.householdId, household.id))
      .orderBy(asc(routines.sortOrder), asc(routineSteps.sortOrder)),
    db
      .select({
        stepId: routineCompletions.stepId,
        completedAt: routineCompletions.completedAt,
        completedByName: users.name,
      })
      .from(routineCompletions)
      .innerJoin(routineSteps, eq(routineCompletions.stepId, routineSteps.id))
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
      .leftJoin(users, eq(routineCompletions.completedBy, users.id))
      .where(
        and(
          eq(routines.householdId, household.id),
          eq(routineCompletions.localDate, localDate),
        ),
      ),
    db
      .select()
      .from(chores)
      .where(eq(chores.householdId, household.id))
      .orderBy(asc(chores.sortOrder)),
    db
      .select({
        choreId: choreCompletions.choreId,
        periodKey: choreCompletions.periodKey,
        completedAt: choreCompletions.completedAt,
        completedByName: users.name,
      })
      .from(choreCompletions)
      .innerJoin(chores, eq(choreCompletions.choreId, chores.id))
      .leftJoin(users, eq(choreCompletions.completedBy, users.id))
      .where(eq(chores.householdId, household.id)),
    db
      .select()
      .from(meals)
      .where(
        and(eq(meals.householdId, household.id), eq(meals.localDate, localDate)),
      ),
    db
      .select({ snackLabel: snackCompletions.snackLabel })
      .from(snackCompletions)
      .where(
        and(
          eq(snackCompletions.householdId, household.id),
          eq(snackCompletions.localDate, localDate),
        ),
      ),
    fetchNapsForDate(household, localDate),
    db
      .select()
      .from(groceryItems)
      .where(
        and(
          eq(groceryItems.householdId, household.id),
          eq(groceryItems.checked, false),
        ),
      )
      .orderBy(asc(groceryItems.category), asc(groceryItems.createdAt)),
    db
      .select()
      .from(householdNotes)
      .where(eq(householdNotes.householdId, household.id))
      .orderBy(desc(householdNotes.pinned), desc(householdNotes.updatedAt)),
    db
      .select()
      .from(familyBirthdays)
      .where(eq(familyBirthdays.householdId, household.id))
      .orderBy(asc(familyBirthdays.name)),
    loadRoutineStreaks(household.id, household.timezone, localDate),
  ]);

  const doneSteps = new Map(routineDone.map((item) => [item.stepId, item]));
  const dueChores = choreRows.filter((chore) =>
    isChoreDueOnDate(
      chore.cadence,
      chore.days,
      localDate,
      household.timezone,
    ),
  );

  const hubModules = await getUserHubModules(userId);
  const birthdayItems = listHouseholdBirthdays(
    familyProfiles,
    familyBirthdayRows.map((row) => ({
      id: row.id,
      profileId: row.profileId,
      name: row.name,
      birthDate: row.birthDate,
      kind: row.kind,
      notes: row.notes,
      giftIdeas: row.giftIdeas,
      notifyDaysBefore: row.notifyDaysBefore,
    })),
    localDate,
  );
  const upcomingBirthdays = birthdayItems.filter((item) => item.daysUntil <= 45);

  const schedule = [
    ...birthdayEventsInRange(
      birthdayItems.map((item) => ({
        id: item.id,
        name: item.name,
        color: item.color,
        birthday: item.birthDate,
        kind: item.kind,
      })),
      localDate,
      localDate,
      household.timezone,
    ),
  ].sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());

  return {
    household: serializeHousehold(household),
    hubModules,
    localDate,
    profiles: familyProfiles,
    routineSteps: routineRows.map((step) => {
      const done = doneSteps.get(step.id);
      return {
        ...step,
        completed: Boolean(done),
        completedAt: done?.completedAt ?? null,
        completedByName: done?.completedByName ?? null,
      };
    }),
    chores: dueChores.map((chore) => {
      const periodKey = chore.cadence === "weekly" ? weeklyKey : localDate;
      const done = choreDone.find(
        (item) => item.choreId === chore.id && item.periodKey === periodKey,
      );
      return {
        id: chore.id,
        title: chore.title,
        profileId: chore.profileId,
        cadence: chore.cadence,
        days: chore.days,
        periodKey,
        completed: Boolean(done),
        completedAt: done?.completedAt ?? null,
        completedByName: done?.completedByName ?? null,
      };
    }),
    meals: todayMeals,
    scheduleEvents: schedule.map((event) => ({
      eventId: event.eventId,
      title: event.title,
      startsAt: event.startsAt.toISOString(),
      endsAt: event.endsAt.toISOString(),
      allDay: event.allDay,
      color: event.color,
      calendarName: event.calendarName,
    })),
    snackOptions: parseSnackOptions(household.snackOptions),
    snackEaten: snackDone.map((item) => item.snackLabel),
    naps: todayNaps.map(serializeNap),
    groceryItems: groceryRows,
    notes: noteRows,
    upcomingBirthdays,
    // Says whether any anniversary exists at all, not just within the next 45 days, so the app can
    // name the module consistently ("Birthdays" or "Celebrations").
    hasAnniversaries: familyBirthdayRows.some((row) => row.kind === "anniversary"),
    routineStreaks,
  };
}
