import { randomUUID } from "node:crypto";
import { and, eq, inArray, lt, lte } from "drizzle-orm";
import { DAVClient, type DAVCalendar } from "tsdav";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  households,
} from "@/db/schema";
import { decryptSecret, encryptSecret } from "@/lib/crypto";
import { upsertDiscoveredCalendars } from "@/lib/calendar/discovery";
import { parseIcalEvent, makeIcalEvent } from "./ical";
import { staleCalendarEventIds } from "./reconcile";

const ICLOUD_URL = "https://caldav.icloud.com";
const FRESH_FOR_MS = 5 * 60 * 1000;
const LOCK_FOR_MS = 2 * 60 * 1000;

function makeClient(username: string, password: string) {
  return new DAVClient({
    serverUrl: ICLOUD_URL,
    credentials: { username, password },
    authMethod: "Basic",
    defaultAccountType: "caldav",
  });
}

export async function discoverICloudCalendars(
  username: string,
  appSpecificPassword: string,
) {
  const client = makeClient(username, appSpecificPassword);
  await client.login();
  const found = await client.fetchCalendars();
  return found.map((calendar) => ({
    url: calendar.url,
    displayName:
      typeof calendar.displayName === "string"
        ? calendar.displayName
        : "iCloud Calendar",
    color: calendar.calendarColor || "#6689a3",
    syncToken: calendar.syncToken,
    ctag: calendar.ctag,
  }));
}

export async function connectICloud(input: {
  householdId: string;
  username: string;
  appSpecificPassword: string;
}) {
  const discovered = await discoverICloudCalendars(
    input.username,
    input.appSpecificPassword,
  );
  if (!discovered.length) throw new Error("No iCloud calendars were found.");

  const connectionId = randomUUID();
  let activeConnectionId: string = connectionId;
  await db.transaction(async (tx) => {
    await tx
      .insert(calendarConnections)
      .values({
        id: connectionId,
        householdId: input.householdId,
        provider: "icloud",
        accountEmail: input.username,
        appleId: input.username,
        encryptedPassword: encryptSecret(input.appSpecificPassword),
        status: "connected",
      })
      .onConflictDoUpdate({
        target: [
          calendarConnections.householdId,
          calendarConnections.provider,
        ],
        set: {
          accountEmail: input.username,
          appleId: input.username,
          encryptedPassword: encryptSecret(input.appSpecificPassword),
          status: "connected",
          errorMessage: null,
          updatedAt: new Date(),
        },
      });

    const activeConnection = await tx
      .select({ id: calendarConnections.id })
      .from(calendarConnections)
      .where(
        and(
          eq(calendarConnections.householdId, input.householdId),
          eq(calendarConnections.provider, "icloud"),
        ),
      )
      .limit(1);
    activeConnectionId = activeConnection[0]?.id ?? connectionId;
  });
  await upsertDiscoveredCalendars(activeConnectionId, discovered, {
    enableNewCalendars: true,
  });
  await syncICloudCalendars(input.householdId, true);
  return discovered.length;
}

export async function syncICloudCalendars(
  householdId: string,
  force = false,
) {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendarConnections.provider, "icloud"),
      ),
    )
    .limit(1);
  const current = connection[0];
  if (!current) return { status: "not-connected" as const };
  const household = await db
    .select({ timezone: households.timezone })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);
  if (!household[0]) return { status: "not-connected" as const };
  const now = Date.now();
  if (
    !force &&
    current.lastSyncedAt &&
    now - current.lastSyncedAt.getTime() < FRESH_FOR_MS
  ) {
    return { status: "fresh" as const };
  }
  if (
    current.syncLockedAt &&
    now - current.syncLockedAt.getTime() < LOCK_FOR_MS
  ) {
    return { status: "already-syncing" as const };
  }

  const locked = await db
    .update(calendarConnections)
    .set({ syncLockedAt: new Date(), status: "syncing" })
    .where(
      and(
        eq(calendarConnections.id, current.id),
        current.syncLockedAt
          ? lt(
              calendarConnections.syncLockedAt,
              new Date(now - LOCK_FOR_MS),
            )
          : eq(calendarConnections.id, current.id),
      ),
    );
  if (locked.rowsAffected === 0) return { status: "already-syncing" as const };

  try {
    const client = makeClient(
      current.appleId ?? current.accountEmail,
      decryptSecret(current.encryptedPassword!),
    );
    await client.login();
    const discovered = await client.fetchCalendars();
    await upsertDiscoveredCalendars(
      current.id,
      discovered.map((calendar) => ({
        url: calendar.url,
        displayName:
          typeof calendar.displayName === "string"
            ? calendar.displayName
            : "iCloud Calendar",
        color: calendar.calendarColor || "#6689a3",
        syncToken: calendar.syncToken,
        ctag: calendar.ctag,
      })),
      { enableNewCalendars: false },
    );
    const selected = await db
      .select()
      .from(calendars)
      .where(
        and(
          eq(calendars.connectionId, current.id),
          eq(calendars.enabled, true),
        ),
      );

    const rangeStart = new Date(now - 45 * 24 * 60 * 60 * 1000);
    const rangeEnd = new Date(now + 370 * 24 * 60 * 60 * 1000);
    const syncStartedAt = new Date(now);
    let count = 0;
    for (const localCalendar of selected) {
      const remoteCalendar = {
        url: localCalendar.url,
        displayName: localCalendar.displayName,
        calendarColor: localCalendar.color,
        syncToken: localCalendar.syncToken,
        ctag: localCalendar.ctag,
      } as DAVCalendar;
      const objects = await client.fetchCalendarObjects({
        calendar: remoteCalendar,
        timeRange: {
          start: rangeStart.toISOString(),
          end: rangeEnd.toISOString(),
        },
      });
      const normalizedObjects = objects.flatMap((object) => {
        if (!object.data || !object.url) return [];
        try {
          return [
            {
              href: object.url,
              etag: object.etag,
              rawIcal: object.data,
              parsed: parseIcalEvent(
                object.data,
                household[0].timezone,
              ),
            },
          ];
        } catch {
          // Ignore non-event calendar objects without leaking calendar content.
          return [];
        }
      });
      const remoteHrefs = new Set(
        normalizedObjects.map((object) => object.href),
      );
      const cachedEvents = await db
        .select({
          id: calendarEvents.id,
          href: calendarEvents.href,
          updatedAt: calendarEvents.updatedAt,
        })
        .from(calendarEvents)
        .where(eq(calendarEvents.calendarId, localCalendar.id));
      const staleIds = staleCalendarEventIds(
        cachedEvents,
        remoteHrefs,
        syncStartedAt,
      );

      await db.transaction(async (tx) => {
        for (const object of normalizedObjects) {
          await tx
            .insert(calendarEvents)
            .values({
              id: randomUUID(),
              calendarId: localCalendar.id,
              href: object.href,
              etag: object.etag,
              rawIcal: object.rawIcal,
              ...object.parsed,
            })
            .onConflictDoUpdate({
              target: [calendarEvents.calendarId, calendarEvents.href],
              set: {
                etag: object.etag,
                rawIcal: object.rawIcal,
                ...object.parsed,
                updatedAt: new Date(),
              },
            });
          count += 1;
        }
        for (let index = 0; index < staleIds.length; index += 200) {
          await tx
            .delete(calendarEvents)
            .where(
              and(
                eq(calendarEvents.calendarId, localCalendar.id),
                inArray(calendarEvents.id, staleIds.slice(index, index + 200)),
                lte(calendarEvents.updatedAt, syncStartedAt),
              ),
            );
        }
      });
    }

    await db
      .update(calendarConnections)
      .set({
        status: "connected",
        errorMessage: null,
        lastSyncedAt: new Date(),
        syncLockedAt: null,
      })
      .where(eq(calendarConnections.id, current.id));
    return { status: "synced" as const, count };
  } catch {
    await db
      .update(calendarConnections)
      .set({
        status: "error",
        errorMessage:
          "iCloud could not be reached. Check the app-specific password.",
        syncLockedAt: null,
      })
      .where(eq(calendarConnections.id, current.id));
    return { status: "error" as const };
  }
}

export async function disconnectICloud(householdId: string) {
  await db
    .delete(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendarConnections.provider, "icloud"),
      ),
    );
}

async function getICloudClientForHousehold(householdId: string) {
  const result = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendarConnections.provider, "icloud"),
      ),
    )
    .limit(1);
  if (!result[0]?.encryptedPassword) {
    throw new Error("iCloud is not connected.");
  }
  const client = makeClient(
    result[0].appleId ?? result[0].accountEmail,
    decryptSecret(result[0].encryptedPassword),
  );
  await client.login();
  return { client, connection: result[0] };
}

export async function createICloudEvent(input: {
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
  const rawIcal = makeIcalEvent({
    uid: input.uid,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
  });
  const { client } = await getICloudClientForHousehold(input.householdId);
  const response = await client.createCalendarObject({
    calendar: {
      url: input.calendarUrl,
      displayName: input.calendarDisplayName,
      calendarColor: input.calendarColor,
    } as DAVCalendar,
    filename: `${input.uid}.ics`,
    iCalString: rawIcal,
  });
  if (!response.ok) throw new Error("iCloud could not create that event.");
}

export async function updateICloudEvent(input: {
  householdId: string;
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
  const rawIcal = makeIcalEvent({
    uid: input.uid,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
  });
  const { client } = await getICloudClientForHousehold(input.householdId);
  const response = await client.updateCalendarObject({
    calendarObject: {
      url: input.eventHref,
      etag: input.eventEtag ?? undefined,
      data: rawIcal,
    },
  });
  if (!response.ok) throw new Error("iCloud could not update that event.");
}

export async function deleteICloudEvent(input: {
  householdId: string;
  eventHref: string;
  eventEtag: string | null;
  rawIcal: string;
}) {
  const { client } = await getICloudClientForHousehold(input.householdId);
  const response = await client.deleteCalendarObject({
    calendarObject: {
      url: input.eventHref,
      etag: input.eventEtag ?? undefined,
      data: input.rawIcal,
    },
  });
  if (!response.ok) throw new Error("iCloud could not delete that event.");
}

export async function moveICloudEvent(input: {
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
  await createICloudEvent({
    householdId: input.householdId,
    calendarUrl: input.toCalendarUrl,
    calendarDisplayName: input.toCalendarDisplayName,
    calendarColor: input.toCalendarColor,
    title: input.title,
    description: input.description,
    location: input.location,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    allDay: input.allDay,
    uid: input.uid,
  });
  await deleteICloudEvent({
    householdId: input.householdId,
    eventHref: input.eventHref,
    eventEtag: input.eventEtag,
    rawIcal: input.rawIcal,
  });
}
