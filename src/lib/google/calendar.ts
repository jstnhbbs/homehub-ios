import { randomUUID } from "node:crypto";
import { and, eq, inArray, lt, lte } from "drizzle-orm";
import { google, type calendar_v3 } from "googleapis";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  households,
} from "@/db/schema";
import { staleCalendarEventIds } from "@/lib/caldav/reconcile";
import { upsertDiscoveredCalendars } from "@/lib/calendar/discovery";
import { calendarSyncIntervalMs } from "@/lib/calendar/sync-interval";
import {
  decryptGoogleAccessToken,
  decryptGoogleRefreshToken,
  exchangeGoogleCode,
  fetchGoogleAccountEmail,
  refreshGoogleAccessToken,
  storeGoogleTokens,
} from "./oauth";
import {
  googleEventToParsed,
  googleEventToRawIcal,
  parsedEventToGoogleBody,
} from "./events";
import type { RemoteCalendarEvent } from "@/lib/calendar/sync";

const LOCK_FOR_MS = 2 * 60 * 1000;

type GoogleConnection = typeof calendarConnections.$inferSelect;
type GoogleCalendarClient = calendar_v3.Calendar;
type LocalCalendar = typeof calendars.$inferSelect;

function isGoogleGoneError(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "response" in error &&
    typeof error.response === "object" &&
    error.response !== null &&
    "status" in error.response &&
    error.response.status === 410
  );
}

function normalizeGoogleEvent(
  event: calendar_v3.Schema$Event,
  timezone: string,
) {
  if (!event.id || event.status === "cancelled") return null;
  const parsed = googleEventToParsed(event, timezone);
  return {
    href: event.id,
    etag: event.etag ?? null,
    rawIcal: googleEventToRawIcal(event, timezone),
    parsed,
  };
}

async function syncGoogleCalendarPageSet(input: {
  client: GoogleCalendarClient;
  localCalendar: LocalCalendar;
  timezone: string;
  now: number;
  incremental: boolean;
}) {
  const rangeStart = new Date(input.now - 45 * 24 * 60 * 60 * 1000);
  const rangeEnd = new Date(input.now + 370 * 24 * 60 * 60 * 1000);
  const syncStartedAt = new Date(input.now);
  const remoteHrefs = new Set<string>();
  const changedObjects: NonNullable<ReturnType<typeof normalizeGoogleEvent>>[] = [];
  const deletedHrefs: string[] = [];
  let pageToken: string | undefined;
  let nextSyncToken: string | null | undefined;

  do {
    const response = await input.client.events.list(
      input.incremental
        ? {
            calendarId: input.localCalendar.url,
            syncToken: input.localCalendar.syncToken ?? undefined,
            showDeleted: true,
            singleEvents: true,
            maxResults: 2500,
            pageToken,
          }
        : {
            calendarId: input.localCalendar.url,
            timeMin: rangeStart.toISOString(),
            timeMax: rangeEnd.toISOString(),
            singleEvents: true,
            maxResults: 2500,
            orderBy: "startTime",
            pageToken,
          },
    );
    for (const event of response.data.items ?? []) {
      if (!event.id) continue;
      if (event.status === "cancelled") {
        deletedHrefs.push(event.id);
        continue;
      }
      const object = normalizeGoogleEvent(event, input.timezone);
      if (!object) continue;
      changedObjects.push(object);
      remoteHrefs.add(object.href);
    }
    pageToken = response.data.nextPageToken ?? undefined;
    nextSyncToken = response.data.nextSyncToken;
  } while (pageToken);

  await db.transaction(async (tx) => {
    for (const object of changedObjects) {
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

    if (input.incremental) {
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
    } else {
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
        remoteHrefs,
        syncStartedAt,
      );
      for (let index = 0; index < staleIds.length; index += 200) {
        await tx
          .delete(calendarEvents)
          .where(
            and(
              eq(calendarEvents.calendarId, input.localCalendar.id),
              inArray(calendarEvents.id, staleIds.slice(index, index + 200)),
              lte(calendarEvents.updatedAt, syncStartedAt),
            ),
          );
      }
    }

    if (nextSyncToken) {
      await tx
        .update(calendars)
        .set({ syncToken: nextSyncToken })
        .where(eq(calendars.id, input.localCalendar.id));
    }
  });

  return changedObjects.length + deletedHrefs.length;
}

async function getValidAccessToken(connection: GoogleConnection) {
  const now = Date.now();
  if (
    connection.encryptedAccessToken &&
    connection.accessTokenExpiresAt &&
    connection.accessTokenExpiresAt.getTime() > now + 60_000
  ) {
    return decryptGoogleAccessToken(connection.encryptedAccessToken);
  }
  if (!connection.encryptedRefreshToken) {
    throw new Error("Google Calendar authorization expired.");
  }
  const refreshToken = decryptGoogleRefreshToken(
    connection.encryptedRefreshToken,
  );
  const tokens = await refreshGoogleAccessToken(refreshToken);
  const stored = storeGoogleTokens({
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresIn: tokens.expires_in,
  });
  await db
    .update(calendarConnections)
    .set({
      encryptedAccessToken: stored.encryptedAccessToken,
      encryptedRefreshToken:
        stored.encryptedRefreshToken ?? connection.encryptedRefreshToken,
      accessTokenExpiresAt: stored.accessTokenExpiresAt,
      updatedAt: new Date(),
    })
    .where(eq(calendarConnections.id, connection.id));
  return tokens.access_token;
}

async function getGoogleClient(connection: GoogleConnection) {
  const accessToken = await getValidAccessToken(connection);
  const auth = new google.auth.OAuth2();
  auth.setCredentials({ access_token: accessToken });
  return google.calendar({ version: "v3", auth });
}

export async function connectGoogleCalendar(input: {
  householdId: string;
  code: string;
}) {
  const tokens = await exchangeGoogleCode(input.code);
  if (!tokens.refresh_token) {
    throw new Error(
      "Google did not return a refresh token. Disconnect and try again.",
    );
  }
  const accountEmail = await fetchGoogleAccountEmail(tokens.access_token);
  const stored = storeGoogleTokens({
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresIn: tokens.expires_in,
  });

  const connectionId = randomUUID();
  let activeConnectionId: string = connectionId;
  await db.transaction(async (tx) => {
    await tx
      .insert(calendarConnections)
      .values({
        id: connectionId,
        householdId: input.householdId,
        provider: "google",
        accountEmail,
        encryptedRefreshToken: stored.encryptedRefreshToken,
        encryptedAccessToken: stored.encryptedAccessToken,
        accessTokenExpiresAt: stored.accessTokenExpiresAt,
        status: "connected",
      })
      .onConflictDoUpdate({
        target: [calendarConnections.householdId, calendarConnections.provider],
        set: {
          accountEmail,
          encryptedRefreshToken: stored.encryptedRefreshToken,
          encryptedAccessToken: stored.encryptedAccessToken,
          accessTokenExpiresAt: stored.accessTokenExpiresAt,
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
          eq(calendarConnections.provider, "google"),
        ),
      )
      .limit(1);
    activeConnectionId = activeConnection[0]?.id ?? connectionId;
  });

  const auth = new google.auth.OAuth2();
  auth.setCredentials({ access_token: tokens.access_token });
  const calendarClient = google.calendar({ version: "v3", auth });
  const list = await calendarClient.calendarList.list({ maxResults: 250 });
  const discovered =
    list.data.items?.flatMap((calendar) =>
      calendar.id
        ? [
            {
              url: calendar.id,
              displayName: calendar.summary ?? "Google Calendar",
              color: calendar.backgroundColor ?? "#4285f4",
            },
          ]
        : [],
    ) ?? [];
  await upsertDiscoveredCalendars(activeConnectionId, discovered, {
    enableNewCalendars: true,
  });

  await syncGoogleCalendars(input.householdId, true);
}

export async function syncGoogleCalendars(
  householdId: string,
  force = false,
) {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendarConnections.provider, "google"),
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
    const client = await getGoogleClient(current);
    const list = await client.calendarList.list({ maxResults: 250 });
    const discovered =
      list.data.items?.flatMap((calendar) =>
        calendar.id
          ? [
              {
                url: calendar.id,
                displayName: calendar.summary ?? "Google Calendar",
                color: calendar.backgroundColor ?? "#4285f4",
              },
            ]
          : [],
      ) ?? [];
    await upsertDiscoveredCalendars(current.id, discovered, {
      enableNewCalendars: false,
    });
    const selected = await db
      .select()
      .from(calendars)
      .where(
        and(
          eq(calendars.connectionId, current.id),
          eq(calendars.enabled, true),
        ),
      );

    let count = 0;

    for (const localCalendar of selected) {
      const incremental = Boolean(localCalendar.syncToken);
      try {
        count += await syncGoogleCalendarPageSet({
          client,
          localCalendar,
          timezone: household[0].timezone,
          now,
          incremental,
        });
      } catch (error) {
        if (!incremental || !isGoogleGoneError(error)) throw error;
        await db
          .delete(calendarEvents)
          .where(eq(calendarEvents.calendarId, localCalendar.id));
        await db
          .update(calendars)
          .set({ syncToken: null })
          .where(eq(calendars.id, localCalendar.id));
        count += await syncGoogleCalendarPageSet({
          client,
          localCalendar: { ...localCalendar, syncToken: null },
          timezone: household[0].timezone,
          now,
          incremental: false,
        });
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
          "Google Calendar could not be reached. Try reconnecting your account.",
        syncLockedAt: null,
      })
      .where(eq(calendarConnections.id, current.id));
    return { status: "error" as const };
  }
}

export async function disconnectGoogleCalendar(householdId: string) {
  await db
    .delete(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, householdId),
        eq(calendarConnections.provider, "google"),
      ),
    );
}

export async function createGoogleEvent(input: {
  householdId: string;
  calendarUrl: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, input.householdId),
        eq(calendarConnections.provider, "google"),
      ),
    )
    .limit(1);
  if (!connection[0]) throw new Error("Google Calendar is not connected.");
  const client = await getGoogleClient(connection[0]);
  const response = await client.events.insert({
    calendarId: input.calendarUrl,
    requestBody: parsedEventToGoogleBody({
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    }),
  });
  if (!response.data.id) throw new Error("Google could not create that event.");
  return {
    href: response.data.id,
    etag: response.data.etag ?? null,
    rawIcal: googleEventToRawIcal(response.data, "UTC"),
  };
}

export async function updateGoogleEvent(input: {
  householdId: string;
  calendarUrl: string;
  eventId: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, input.householdId),
        eq(calendarConnections.provider, "google"),
      ),
    )
    .limit(1);
  if (!connection[0]) throw new Error("Google Calendar is not connected.");
  const client = await getGoogleClient(connection[0]);
  const response = await client.events.update({
    calendarId: input.calendarUrl,
    eventId: input.eventId,
    requestBody: parsedEventToGoogleBody({
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    }),
  });
  return {
    href: response.data.id ?? input.eventId,
    etag: response.data.etag ?? null,
    rawIcal: googleEventToRawIcal(response.data, "UTC"),
  };
}

export async function moveGoogleEvent(input: {
  householdId: string;
  fromCalendarUrl: string;
  toCalendarUrl: string;
  eventId: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  uid: string;
}): Promise<RemoteCalendarEvent> {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, input.householdId),
        eq(calendarConnections.provider, "google"),
      ),
    )
    .limit(1);
  if (!connection[0]) throw new Error("Google Calendar is not connected.");
  const client = await getGoogleClient(connection[0]);
  const moved = await client.events.move({
    calendarId: input.fromCalendarUrl,
    eventId: input.eventId,
    destination: input.toCalendarUrl,
  });
  const eventId = moved.data.id ?? input.eventId;
  const response = await client.events.update({
    calendarId: input.toCalendarUrl,
    eventId,
    requestBody: parsedEventToGoogleBody({
      title: input.title,
      description: input.description,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      allDay: input.allDay,
      uid: input.uid,
    }),
  });
  return {
    href: response.data.id ?? eventId,
    etag: response.data.etag ?? null,
    rawIcal: googleEventToRawIcal(response.data, "UTC"),
  };
}

export async function deleteGoogleEvent(input: {
  householdId: string;
  calendarUrl: string;
  eventId: string;
}) {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(
      and(
        eq(calendarConnections.householdId, input.householdId),
        eq(calendarConnections.provider, "google"),
      ),
    )
    .limit(1);
  if (!connection[0]) throw new Error("Google Calendar is not connected.");
  const client = await getGoogleClient(connection[0]);
  await client.events.delete({
    calendarId: input.calendarUrl,
    eventId: input.eventId,
  });
}
