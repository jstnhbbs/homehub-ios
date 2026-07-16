import { randomUUID } from "node:crypto";
import { and, eq, inArray, lt, lte } from "drizzle-orm";
import { google } from "googleapis";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  households,
} from "@/db/schema";
import { staleCalendarEventIds } from "@/lib/caldav/reconcile";
import { upsertDiscoveredCalendars } from "@/lib/calendar/discovery";
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

const FRESH_FOR_MS = 5 * 60 * 1000;
const LOCK_FOR_MS = 2 * 60 * 1000;

type GoogleConnection = typeof calendarConnections.$inferSelect;

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

    const rangeStart = new Date(now - 45 * 24 * 60 * 60 * 1000);
    const rangeEnd = new Date(now + 370 * 24 * 60 * 60 * 1000);
    const syncStartedAt = new Date(now);
    let count = 0;

    for (const localCalendar of selected) {
      const response = await client.events.list({
        calendarId: localCalendar.url,
        timeMin: rangeStart.toISOString(),
        timeMax: rangeEnd.toISOString(),
        singleEvents: true,
        maxResults: 2500,
        orderBy: "startTime",
      });
      const items = response.data.items ?? [];
      const normalizedObjects = items.flatMap((event) => {
        if (!event.id) return [];
        try {
          const parsed = googleEventToParsed(event, household[0].timezone);
          return [
            {
              href: event.id,
              etag: event.etag ?? null,
              rawIcal: googleEventToRawIcal(event, household[0].timezone),
              parsed,
            },
          ];
        } catch {
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
  location?: string;
  startsAt: Date;
  endsAt: Date;
  uid: string;
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
  const response = await client.events.insert({
    calendarId: input.calendarUrl,
    requestBody: parsedEventToGoogleBody({
      title: input.title,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      uid: input.uid,
    }),
  });
  if (!response.data.id) throw new Error("Google could not create that event.");
}

export async function updateGoogleEvent(input: {
  householdId: string;
  calendarUrl: string;
  eventId: string;
  title: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  uid: string;
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
  await client.events.update({
    calendarId: input.calendarUrl,
    eventId: input.eventId,
    requestBody: parsedEventToGoogleBody({
      title: input.title,
      location: input.location,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      uid: input.uid,
    }),
  });
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
