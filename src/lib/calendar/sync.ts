import {
  syncGoogleCalendars,
  createGoogleEvent,
  updateGoogleEvent,
  deleteGoogleEvent,
  moveGoogleEvent,
} from "@/lib/google/calendar";
import {
  syncICloudCalendars,
  createICloudEvent,
  updateICloudEvent,
  deleteICloudEvent,
  moveICloudEvent,
} from "@/lib/caldav/client";
import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { calendarEvents } from "@/db/schema";

export type RemoteCalendarEvent = {
  href: string;
  etag: string | null;
  rawIcal: string;
};

export type SyncResult =
  | { status: "not-connected" }
  | { status: "fresh" }
  | { status: "already-syncing" }
  | { status: "synced"; count: number }
  | { status: "error" };

export async function syncHouseholdCalendars(
  householdId: string,
  force = false,
): Promise<{ results: SyncResult[] }> {
  const [icloud, google] = await Promise.all([
    syncICloudCalendars(householdId, force),
    syncGoogleCalendars(householdId, force),
  ]);
  return { results: [icloud, google] };
}

export async function createRemoteCalendarEvent(input: {
  provider: "icloud" | "google";
  householdId: string;
  calendarUrl: string;
  calendarDisplayName: string;
  calendarColor: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  if (input.provider === "google") {
    return createGoogleEvent({
      householdId: input.householdId,
      calendarUrl: input.calendarUrl,
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    });
  }
  return createICloudEvent({
    householdId: input.householdId,
    calendarUrl: input.calendarUrl,
    calendarDisplayName: input.calendarDisplayName,
    calendarColor: input.calendarColor,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
    uid: input.uid,
  });
}

export async function updateRemoteCalendarEvent(input: {
  provider: "icloud" | "google";
  householdId: string;
  calendarUrl: string;
  eventHref: string;
  eventEtag: string | null;
  rawIcal: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  if (input.provider === "google") {
    return updateGoogleEvent({
      householdId: input.householdId,
      calendarUrl: input.calendarUrl,
      eventId: input.eventHref,
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    });
  }
  return updateICloudEvent({
    householdId: input.householdId,
    eventHref: input.eventHref,
    eventEtag: input.eventEtag,
    rawIcal: input.rawIcal,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
    uid: input.uid,
  });
}

export async function moveRemoteCalendarEvent(input: {
  provider: "icloud" | "google";
  householdId: string;
  fromCalendarUrl: string;
  toCalendarUrl: string;
  toCalendarDisplayName: string;
  toCalendarColor: string;
  eventHref: string;
  eventEtag: string | null;
  rawIcal: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  if (input.provider === "google") {
    return moveGoogleEvent({
      householdId: input.householdId,
      fromCalendarUrl: input.fromCalendarUrl,
      toCalendarUrl: input.toCalendarUrl,
      eventId: input.eventHref,
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    });
  }
  return moveICloudEvent({
    householdId: input.householdId,
    fromCalendarUrl: input.fromCalendarUrl,
    toCalendarUrl: input.toCalendarUrl,
    toCalendarDisplayName: input.toCalendarDisplayName,
    toCalendarColor: input.toCalendarColor,
    eventHref: input.eventHref,
    eventEtag: input.eventEtag,
    rawIcal: input.rawIcal,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
    uid: input.uid,
  });
}

export async function deleteRemoteCalendarEvent(input: {
  provider: "icloud" | "google";
  householdId: string;
  calendarUrl: string;
  eventHref: string;
  eventEtag: string | null;
  rawIcal: string;
}) {
  if (input.provider === "google") {
    await deleteGoogleEvent({
      householdId: input.householdId,
      calendarUrl: input.calendarUrl,
      eventId: input.eventHref,
    });
    return;
  }
  await deleteICloudEvent({
    householdId: input.householdId,
    eventHref: input.eventHref,
    eventEtag: input.eventEtag,
    rawIcal: input.rawIcal,
  });
}

export async function upsertCachedCalendarEvent(input: {
  calendarId: string;
  remote: RemoteCalendarEvent;
  uid: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  recurrenceRule?: string | null;
}) {
  await db
    .insert(calendarEvents)
    .values({
      id: randomUUID(),
      calendarId: input.calendarId,
      href: input.remote.href,
      etag: input.remote.etag,
      rawIcal: input.remote.rawIcal,
      uid: input.uid,
      title: input.title,
      description: input.description ?? null,
      location: input.location ?? null,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      recurrenceRule: input.recurrenceRule ?? null,
    })
    .onConflictDoUpdate({
      target: [calendarEvents.calendarId, calendarEvents.href],
      set: {
        etag: input.remote.etag,
        rawIcal: input.remote.rawIcal,
        uid: input.uid,
        title: input.title,
        description: input.description ?? null,
        location: input.location ?? null,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
        allDay: input.allDay,
        recurrenceRule: input.recurrenceRule ?? null,
        updatedAt: new Date(),
      },
    });
}

export async function deleteCachedCalendarEvent(eventId: string) {
  await db.delete(calendarEvents).where(eq(calendarEvents.id, eventId));
}
