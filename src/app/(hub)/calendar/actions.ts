"use server";

import { randomUUID } from "node:crypto";
import { and, eq } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
} from "@/db/schema";
import {
  eventTimesFromForm,
  parseCalendarEventForm,
} from "@/lib/calendar/event-input";
import {
  createRemoteCalendarEvent,
  deleteRemoteCalendarEvent,
  moveRemoteCalendarEvent,
  syncHouseholdCalendars,
  updateRemoteCalendarEvent,
} from "@/lib/calendar/sync";
import { requireParentHousehold } from "@/lib/household";

async function loadCalendar(calendarId: string, householdId: string) {
  const selected = await db
    .select({
      id: calendars.id,
      url: calendars.url,
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
        eq(calendars.id, calendarId),
        eq(calendarConnections.householdId, householdId),
      ),
    )
    .limit(1);
  if (!selected[0]) throw new Error("Calendar not found.");
  return selected[0];
}

export async function createCalendarEvent(formData: FormData) {
  const household = await requireParentHousehold();
  const input = parseCalendarEventForm(formData);
  const calendar = await loadCalendar(input.calendarId, household.id);
  const { startsAt, endsAt, allDay } = eventTimesFromForm(
    input,
    household.timezone,
  );

  const uid = `${randomUUID()}@homehub`;
  await createRemoteCalendarEvent({
    provider: calendar.provider,
    householdId: household.id,
    calendarUrl: calendar.url,
    calendarDisplayName: calendar.displayName,
    calendarColor: calendar.color,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt,
    endsAt,
    allDay,
    uid,
  });
  await syncHouseholdCalendars(household.id, true);
  revalidatePath("/", "layout");
}

export async function updateCalendarEvent(formData: FormData) {
  const household = await requireParentHousehold();
  const eventId = z.string().uuid().parse(formData.get("eventId"));
  const input = parseCalendarEventForm(formData);
  const targetCalendar = await loadCalendar(input.calendarId, household.id);
  const { startsAt, endsAt, allDay } = eventTimesFromForm(
    input,
    household.timezone,
  );

  const event = await db
    .select({
      id: calendarEvents.id,
      uid: calendarEvents.uid,
      href: calendarEvents.href,
      etag: calendarEvents.etag,
      rawIcal: calendarEvents.rawIcal,
      calendarId: calendarEvents.calendarId,
      calendarUrl: calendars.url,
      calendarDisplayName: calendars.displayName,
      calendarColor: calendars.color,
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
        eq(calendarEvents.id, eventId),
        eq(calendarConnections.householdId, household.id),
      ),
    )
    .limit(1);
  if (!event[0]) throw new Error("Event not found.");
  if (event[0].provider !== targetCalendar.provider) {
    throw new Error("Events can only move between calendars on the same provider.");
  }

  const payload = {
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt,
    endsAt,
    allDay,
    uid: event[0].uid,
  };

  if (input.calendarId !== event[0].calendarId) {
    await moveRemoteCalendarEvent({
      provider: event[0].provider,
      householdId: household.id,
      fromCalendarUrl: event[0].calendarUrl,
      toCalendarUrl: targetCalendar.url,
      toCalendarDisplayName: targetCalendar.displayName,
      toCalendarColor: targetCalendar.color,
      eventHref: event[0].href,
      eventEtag: event[0].etag,
      rawIcal: event[0].rawIcal,
      ...payload,
    });
    await db.delete(calendarEvents).where(eq(calendarEvents.id, eventId));
  } else {
    await updateRemoteCalendarEvent({
      provider: event[0].provider,
      householdId: household.id,
      calendarUrl: event[0].calendarUrl,
      eventHref: event[0].href,
      eventEtag: event[0].etag,
      rawIcal: event[0].rawIcal,
      ...payload,
    });
  }

  await syncHouseholdCalendars(household.id, true);
  revalidatePath("/", "layout");
}

export async function deleteCalendarEvent(formData: FormData) {
  const household = await requireParentHousehold();
  const eventId = z.string().uuid().parse(formData.get("eventId"));
  const event = await db
    .select({
      id: calendarEvents.id,
      href: calendarEvents.href,
      etag: calendarEvents.etag,
      rawIcal: calendarEvents.rawIcal,
      calendarUrl: calendars.url,
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
        eq(calendarEvents.id, eventId),
        eq(calendarConnections.householdId, household.id),
      ),
    )
    .limit(1);
  if (!event[0]) throw new Error("Event not found.");
  await deleteRemoteCalendarEvent({
    provider: event[0].provider,
    householdId: household.id,
    calendarUrl: event[0].calendarUrl,
    eventHref: event[0].href,
    eventEtag: event[0].etag,
    rawIcal: event[0].rawIcal,
  });
  await db.delete(calendarEvents).where(eq(calendarEvents.id, eventId));
  revalidatePath("/", "layout");
}
