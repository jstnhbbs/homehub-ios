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
}) {
  if (input.provider === "google") {
    await createGoogleEvent({
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
    return;
  }
  await createICloudEvent({
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
}) {
  if (input.provider === "google") {
    await updateGoogleEvent({
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
    return;
  }
  await updateICloudEvent({
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
}) {
  if (input.provider === "google") {
    await moveGoogleEvent({
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
    return;
  }
  await moveICloudEvent({
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
