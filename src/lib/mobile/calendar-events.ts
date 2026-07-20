import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  profiles,
} from "@/db/schema";
import { birthdayEventsInRange } from "@/lib/birthdays";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { fromZonedTime } from "date-fns-tz";
import type { getCurrentHousehold } from "@/lib/household";

type Household = NonNullable<Awaited<ReturnType<typeof getCurrentHousehold>>>;

export type CalendarOccurrence = {
  eventId: string;
  calendarId: string | null;
  title: string;
  description: string | null;
  location: string | null;
  startsAt: string;
  endsAt: string;
  allDay: boolean;
  color: string;
  calendarName: string;
  provider: "icloud" | "google" | null;
  isBirthday: boolean;
  profileId: string | null;
};

export async function listHouseholdCalendars(householdId: string) {
  return db
    .select({
      id: calendars.id,
      connectionId: calendars.connectionId,
      displayName: calendars.displayName,
      color: calendars.color,
      enabled: calendars.enabled,
      provider: calendarConnections.provider,
    })
    .from(calendars)
    .innerJoin(
      calendarConnections,
      eq(calendars.connectionId, calendarConnections.id),
    )
    .where(eq(calendarConnections.householdId, householdId));
}

export async function listEnabledCalendars(householdId: string) {
  return db
    .select({
      id: calendars.id,
      displayName: calendars.displayName,
      color: calendars.color,
      provider: calendarConnections.provider,
    })
    .from(calendars)
    .innerJoin(
      calendarConnections,
      eq(calendars.connectionId, calendarConnections.id),
    )
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendars.enabled, true),
      ),
    );
}

export async function buildCalendarOccurrences(
  household: Household,
  start: string,
  end: string,
  query = "",
): Promise<CalendarOccurrence[]> {
  const rangeStart = fromZonedTime(`${start}T00:00:00`, household.timezone);
  const rangeEnd = fromZonedTime(`${end}T23:59:59`, household.timezone);

  const [cachedEvents, familyProfiles] = await Promise.all([
    db
      .select({
        id: calendarEvents.id,
        calendarId: calendarEvents.calendarId,
        rawIcal: calendarEvents.rawIcal,
        description: calendarEvents.description,
        location: calendarEvents.location,
        color: calendars.color,
        calendarName: calendars.displayName,
        provider: calendarConnections.provider,
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
        ),
      ),
    db
      .select({
        id: profiles.id,
        name: profiles.name,
        color: profiles.color,
        birthday: profiles.birthday,
      })
      .from(profiles)
      .where(eq(profiles.householdId, household.id)),
  ]);

  const normalizedQuery = query.trim().toLocaleLowerCase();
  const occurrences: CalendarOccurrence[] = [
    ...cachedEvents.flatMap((event) =>
      expandIcalEvent(
        event.rawIcal,
        rangeStart,
        rangeEnd,
        household.timezone,
      ).map((occurrence) => ({
        eventId: event.id,
        calendarId: event.calendarId,
        title: occurrence.title,
        description: occurrence.description || event.description,
        location: occurrence.location || event.location,
        startsAt: occurrence.startsAt.toISOString(),
        endsAt: occurrence.endsAt.toISOString(),
        allDay: occurrence.allDay,
        color: event.color,
        calendarName: event.calendarName,
        provider: event.provider,
        isBirthday: false as const,
        profileId: null,
      })),
    ),
    ...birthdayEventsInRange(
      familyProfiles,
      start,
      end,
      household.timezone,
    ).map((event) => ({
      eventId: event.eventId,
      calendarId: null,
      title: event.title,
      description: event.description,
      location: event.location,
      startsAt: event.startsAt.toISOString(),
      endsAt: event.endsAt.toISOString(),
      allDay: event.allDay,
      color: event.color,
      calendarName: event.calendarName,
      provider: null,
      isBirthday: true as const,
      profileId: event.profileId,
    })),
  ];

  if (!normalizedQuery) return occurrences;

  return occurrences.filter((event) =>
    `${event.title} ${event.location ?? ""} ${event.calendarName}`
      .toLocaleLowerCase()
      .includes(normalizedQuery),
  );
}
