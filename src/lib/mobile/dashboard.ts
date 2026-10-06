import { and, asc, desc, eq, inArray } from "drizzle-orm";
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
import { choreState } from "@/lib/chores";
import { localDateIn, weekKey } from "@/lib/dates";
import { parseSnackOptions, snackEatenLabels } from "@/lib/meals/snacks";
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
    hubModules,
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
      .where(
        and(
          eq(chores.householdId, household.id),
          // One-offs are keyed "once", weekly chores by week and everything else by day, so these
          // are all the dashboard reads. Without this every completion ever recorded came back.
          inArray(choreCompletions.periodKey, [localDate, weeklyKey, "once"]),
        ),
      ),
    db
      .select()
      .from(meals)
      .where(
        and(eq(meals.householdId, household.id), eq(meals.localDate, localDate)),
      ),
    db
      .select({
        snackLabel: snackCompletions.snackLabel,
        profileId: snackCompletions.profileId,
      })
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
    getUserHubModules(userId),
  ]);

  const doneSteps = new Map(routineDone.map((item) => [item.stepId, item]));
  const now = new Date();
  const choreItems = choreRows.map((chore) => {
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
  const dueChores = choreItems.filter(({ state }) => state.dueToday);

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
  // nextBirthdayOccurrence always rolls to the soonest occurrence (this year or next), so
  // daysUntil never exceeds about a year regardless of this cutoff; it exists so a change to that
  // logic can't silently make the dashboard payload unbounded, not to hide anything further out.
  const upcomingBirthdays = birthdayItems.filter((item) => item.daysUntil <= 365);

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

  const childIds = familyProfiles
    .filter((profile) => profile.profileType === "child")
    .map((profile) => profile.id);
  // Per-child tracking only means something when there is a child to track.
  const snacksPerChild = household.snacksPerChild && childIds.length > 0;

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
    chores: dueChores.map(({ chore, done, state }) => ({
      id: chore.id,
      title: chore.title,
      profileId: chore.profileId,
      cadence: chore.cadence,
      days: chore.days,
      dueDate: chore.dueDate,
      dueTime: chore.dueTime,
      repeatUnit: chore.repeatUnit,
      repeatInterval: chore.repeatInterval,
      periodKey: state.periodKey,
      completed: state.completed,
      completedAt: done?.completedAt ?? null,
      completedByName: done?.completedByName ?? null,
      overdue: state.overdue,
    })),
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
    snacksPerChild: snacksPerChild,
    snackCompletions: snackDone.map((item) => ({
      snackLabel: item.snackLabel,
      profileId: item.profileId || null,
    })),
    snackEaten: snackEatenLabels(snackDone, snacksPerChild, childIds),
    naps: todayNaps.map(serializeNap),
    groceryItems: groceryRows,
    notes: noteRows,
    upcomingBirthdays,
    // Says whether any anniversary exists at all, not just within upcomingBirthdays' window, so
    // the app can name the module consistently ("Birthdays" or "Celebrations").
    hasAnniversaries: familyBirthdayRows.some((row) => row.kind === "anniversary"),
    routineStreaks,
  };
}
