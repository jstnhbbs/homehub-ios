import { and, asc, desc, eq, gte, isNotNull, lte, or } from "drizzle-orm";
import { fromZonedTime } from "date-fns-tz";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
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
} from "@/db/schema";
import { birthdayEventsInRange } from "@/lib/birthdays";
import { listHouseholdBirthdays } from "@/lib/family-birthdays";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { isChoreDueOnDate } from "@/lib/chores";
import { localDateIn, weekKey } from "@/lib/dates";
import { parseSnackOptions } from "@/lib/meals/snacks";
import { fetchNapsForDate, serializeNap } from "@/lib/naps/store";
import type { getCurrentHousehold } from "@/lib/household";
import { getUserHubModules } from "@/lib/hub-modules-store";
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
      .select({ stepId: routineCompletions.stepId })
      .from(routineCompletions)
      .innerJoin(routineSteps, eq(routineCompletions.stepId, routineSteps.id))
      .innerJoin(routines, eq(routineSteps.routineId, routines.id))
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
      })
      .from(choreCompletions)
      .innerJoin(chores, eq(choreCompletions.choreId, chores.id))
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
  ]);

  const doneSteps = new Set(routineDone.map((item) => item.stepId));
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
    routineSteps: routineRows.map((step) => ({
      ...step,
      completed: doneSteps.has(step.id),
    })),
    chores: dueChores.map((chore) => {
      const periodKey = chore.cadence === "weekly" ? weeklyKey : localDate;
      const completed = choreDone.some(
        (item) => item.choreId === chore.id && item.periodKey === periodKey,
      );
      return {
        id: chore.id,
        title: chore.title,
        profileId: chore.profileId,
        cadence: chore.cadence,
        days: chore.days,
        periodKey,
        completed,
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
  };
}

export async function buildCalendarEvents(
  household: Household,
  start: string,
  end: string,
) {
  const dayStart = fromZonedTime(`${start}T00:00:00`, household.timezone);
  const dayEnd = fromZonedTime(`${end}T23:59:59`, household.timezone);
  const familyProfiles = await db
    .select()
    .from(profiles)
    .where(eq(profiles.householdId, household.id))
    .orderBy(asc(profiles.sortOrder));

  const eventRows = await db
    .select({
      id: calendarEvents.id,
      rawIcal: calendarEvents.rawIcal,
      color: calendars.color,
      calendarName: calendars.displayName,
    })
    .from(calendarEvents)
    .innerJoin(calendars, eq(calendarEvents.calendarId, calendars.id))
    .innerJoin(
      calendarConnections,
      eq(calendars.connectionId, calendarConnections.id),
    )
    .where(
      and(
        eq(calendarConnections.householdId, household.id),
        eq(calendars.enabled, true),
        or(
          isNotNull(calendarEvents.recurrenceRule),
          and(
            lte(calendarEvents.startsAt, dayEnd),
            gte(calendarEvents.endsAt, dayStart),
          ),
        ),
      ),
    );

  const schedule = [
    ...eventRows.flatMap((event) =>
      expandIcalEvent(
        event.rawIcal,
        dayStart,
        dayEnd,
        household.timezone,
      ).map((occurrence) => ({
        ...occurrence,
        eventId: event.id,
        color: event.color,
        calendarName: event.calendarName,
      })),
    ),
    ...birthdayEventsInRange(familyProfiles, start, end, household.timezone),
  ].sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());

  return schedule.map((event) => ({
    eventId: event.eventId,
    title: event.title,
    startsAt: event.startsAt.toISOString(),
    endsAt: event.endsAt.toISOString(),
    allDay: event.allDay,
    color: event.color,
    calendarName: event.calendarName,
  }));
}
