import { randomUUID } from "node:crypto";
import { and, eq, inArray, lt, lte } from "drizzle-orm";
import { DAVClient, type DAVCalendar, type DAVCalendarObject } from "tsdav";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  households,
} from "@/db/schema";
import { decryptSecret, encryptSecret } from "@/lib/crypto";
import { upsertDiscoveredCalendars } from "@/lib/calendar/discovery";
import { calendarSyncIntervalMs } from "@/lib/calendar/sync-interval";
import { parseIcalEvent, makeIcalEvent } from "./ical";
import { staleCalendarEventIds } from "./reconcile";
import type { RemoteCalendarEvent } from "@/lib/calendar/sync";

const ICLOUD_URL = "https://caldav.icloud.com";
const LOCK_FOR_MS = 2 * 60 * 1000;
type LocalCalendar = typeof calendars.$inferSelect;

function calendarObjectUrl(calendarUrl: string, filename: string) {
  return new URL(filename, calendarUrl.endsWith("/") ? calendarUrl : `${calendarUrl}/`)
    .href;
}

function calendarResponseObjectUrl(calendarUrl: string, filename: string, response: Response) {
  const location = response.headers.get("location");
  if (location) return new URL(location, calendarUrl).href;
  return calendarObjectUrl(calendarUrl, filename);
}

function normalizeDavObject(object: DAVCalendarObject, timezone: string) {
  if (!object.data || !object.url) return null;
  try {
    return {
      href: object.url,
      etag: object.etag ?? null,
      rawIcal: object.data,
      parsed: parseIcalEvent(object.data, timezone),
    };
  } catch {
    // Ignore non-event calendar objects without leaking calendar content.
    return null;
  }
}

async function applyDavObjects(input: {
  localCalendar: LocalCalendar;
  timezone: string;
  objects: DAVCalendarObject[];
  deletedHrefs?: string[];
  fullRemoteHrefs?: Set<string>;
  syncStartedAt?: Date;
}) {
  const normalizedObjects = input.objects.flatMap((object) => {
    const normalized = normalizeDavObject(object, input.timezone);
    return normalized ? [normalized] : [];
  });

  await db.transaction(async (tx) => {
    for (const object of normalizedObjects) {
      await tx
        .insert(calendarEvents)
        .values({
          id: randomUUID(),
          calendarId: input.localCalendar.id,
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
    }

    const deletedHrefs = input.deletedHrefs ?? [];
    for (let index = 0; index < deletedHrefs.length; index += 200) {
      await tx
        .delete(calendarEvents)
        .where(
          and(
            eq(calendarEvents.calendarId, input.localCalendar.id),
            inArray(calendarEvents.href, deletedHrefs.slice(index, index + 200)),
          ),
        );
    }

    if (input.fullRemoteHrefs && input.syncStartedAt) {
      const cachedEvents = await tx
        .select({
          id: calendarEvents.id,
          href: calendarEvents.href,
          updatedAt: calendarEvents.updatedAt,
        })
        .from(calendarEvents)
        .where(eq(calendarEvents.calendarId, input.localCalendar.id));
      const staleIds = staleCalendarEventIds(
        cachedEvents,
        input.fullRemoteHrefs,
        input.syncStartedAt,
      );
      for (let index = 0; index < staleIds.length; index += 200) {
        await tx
          .delete(calendarEvents)
          .where(
            and(
              eq(calendarEvents.calendarId, input.localCalendar.id),
              inArray(calendarEvents.id, staleIds.slice(index, index + 200)),
              lte(calendarEvents.updatedAt, input.syncStartedAt),
            ),
          );
      }
    }
  });

  return normalizedObjects.length + (input.deletedHrefs?.length ?? 0);
}

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
    .select({
      timezone: households.timezone,
      calendarSyncIntervalMinutes: households.calendarSyncIntervalMinutes,
    })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);
  if (!household[0]) return { status: "not-connected" as const };
  const freshForMs = calendarSyncIntervalMs(
    household[0].calendarSyncIntervalMinutes,
  );
  const now = Date.now();
  if (!force && freshForMs <= 0) {
    return { status: "fresh" as const };
  }
  if (
    !force &&
    current.lastSyncedAt &&
    now - current.lastSyncedAt.getTime() < freshForMs
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
    const selected = await db
      .select()
      .from(calendars)
      .where(
        and(
          eq(calendars.connectionId, current.id),
          eq(calendars.enabled, true),
        ),
      );
    const discovered = await client.fetchCalendars();
    const remoteByUrl = new Map(
      discovered.map((calendar) => [calendar.url, calendar]),
    );
    await upsertDiscoveredCalendars(
      current.id,
      discovered.map((calendar) => ({
        url: calendar.url,
        displayName:
          typeof calendar.displayName === "string"
            ? calendar.displayName
            : "iCloud Calendar",
        color: calendar.calendarColor || "#6689a3",
      })),
      { enableNewCalendars: false },
    );

    const rangeStart = new Date(now - 45 * 24 * 60 * 60 * 1000);
    const rangeEnd = new Date(now + 370 * 24 * 60 * 60 * 1000);
    const syncStartedAt = new Date(now);
    let count = 0;
    for (const localCalendar of selected) {
      const discoveredCalendar = remoteByUrl.get(localCalendar.url);
      const cachedEvents = await db
        .select({
          href: calendarEvents.href,
          etag: calendarEvents.etag,
          rawIcal: calendarEvents.rawIcal,
        })
        .from(calendarEvents)
        .where(eq(calendarEvents.calendarId, localCalendar.id));
      const syncTokenMatches =
        discoveredCalendar?.syncToken &&
        discoveredCalendar.syncToken === localCalendar.syncToken;
      const ctagMatches =
        !discoveredCalendar?.syncToken &&
        discoveredCalendar?.ctag &&
        discoveredCalendar.ctag === localCalendar.ctag;
      if (cachedEvents.length > 0 && (syncTokenMatches || ctagMatches)) {
        continue;
      }

      const remoteCalendar = {
        ...(discoveredCalendar ?? {}),
        url: localCalendar.url,
        displayName:
          discoveredCalendar?.displayName ?? localCalendar.displayName,
        calendarColor:
          discoveredCalendar?.calendarColor ?? localCalendar.color,
        syncToken: localCalendar.syncToken,
        ctag: localCalendar.ctag,
      } as DAVCalendar;

      try {
        const result = await client.smartCollectionSyncDetailed({
          account: client.account,
          collection: {
            ...remoteCalendar,
            objects: cachedEvents.map((event) => ({
              url: event.href,
              etag: event.etag ?? undefined,
              data: event.rawIcal,
            })),
            objectMultiGet: client.calendarMultiGet.bind(client),
            fetchObjects: (params?: { collection: DAVCalendar }) =>
              params
                ? client.fetchCalendarObjects({
                    calendar: params.collection,
                    timeRange: {
                      start: rangeStart.toISOString(),
                      end: rangeEnd.toISOString(),
                    },
                  })
                : Promise.resolve([]),
          },
        });
        count += await applyDavObjects({
          localCalendar,
          timezone: household[0].timezone,
          objects: [
            ...result.objects.created,
            ...result.objects.updated,
          ] as DAVCalendarObject[],
          deletedHrefs: result.objects.deleted.map((object) => object.url),
        });
        await db
          .update(calendars)
          .set({
            ctag: result.ctag ?? discoveredCalendar?.ctag ?? localCalendar.ctag,
            syncToken:
              result.syncToken ??
              discoveredCalendar?.syncToken ??
              localCalendar.syncToken,
          })
          .where(eq(calendars.id, localCalendar.id));
      } catch {
        const objects = await client.fetchCalendarObjects({
          calendar: remoteCalendar,
          timeRange: {
            start: rangeStart.toISOString(),
            end: rangeEnd.toISOString(),
          },
        });
        count += await applyDavObjects({
          localCalendar,
          timezone: household[0].timezone,
          objects,
          fullRemoteHrefs: new Set(
            objects.flatMap((object) => (object.url ? [object.url] : [])),
          ),
          syncStartedAt,
        });
        await db
          .update(calendars)
          .set({
            ctag: discoveredCalendar?.ctag ?? localCalendar.ctag,
            syncToken: discoveredCalendar?.syncToken ?? localCalendar.syncToken,
          })
          .where(eq(calendars.id, localCalendar.id));
      }
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
}): Promise<RemoteCalendarEvent> {
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
  const filename = `${input.uid}.ics`;
  const response = await client.createCalendarObject({
    calendar: {
      url: input.calendarUrl,
      displayName: input.calendarDisplayName,
      calendarColor: input.calendarColor,
    } as DAVCalendar,
    filename,
    iCalString: rawIcal,
  });
  if (!response.ok) throw new Error("iCloud could not create that event.");
  return {
    href: calendarResponseObjectUrl(input.calendarUrl, filename, response),
    etag: response.headers.get("etag"),
    rawIcal,
  };
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
}): Promise<RemoteCalendarEvent> {
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
  return {
    href: input.eventHref,
    etag: response.headers.get("etag") ?? input.eventEtag,
    rawIcal,
  };
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
}): Promise<RemoteCalendarEvent> {
  const created = await createICloudEvent({
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
  return created;
}
