import { randomUUID } from "node:crypto";
import { and, eq, lt } from "drizzle-orm";
import { DAVClient, type DAVCalendar } from "tsdav";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
} from "@/db/schema";
import { decryptSecret, encryptSecret } from "@/lib/crypto";
import { parseIcalEvent } from "./ical";

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
  await db.transaction(async (tx) => {
    await tx
      .insert(calendarConnections)
      .values({
        id: connectionId,
        householdId: input.householdId,
        appleId: input.username,
        encryptedPassword: encryptSecret(input.appSpecificPassword),
        status: "connected",
      })
      .onConflictDoUpdate({
        target: calendarConnections.householdId,
        set: {
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
      .where(eq(calendarConnections.householdId, input.householdId))
      .limit(1);
    const id = activeConnection[0]?.id ?? connectionId;
    for (const calendar of discovered) {
      await tx
        .insert(calendars)
        .values({ id: randomUUID(), connectionId: id, ...calendar })
        .onConflictDoUpdate({
          target: [calendars.connectionId, calendars.url],
          set: {
            displayName: calendar.displayName,
            color: calendar.color,
            syncToken: calendar.syncToken,
            ctag: calendar.ctag,
          },
        });
    }
  });
  await syncHouseholdCalendars(input.householdId, true);
  return discovered.length;
}

export async function syncHouseholdCalendars(
  householdId: string,
  force = false,
) {
  const connection = await db
    .select()
    .from(calendarConnections)
    .where(eq(calendarConnections.householdId, householdId))
    .limit(1);
  const current = connection[0];
  if (!current) return { status: "not-connected" as const };
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
      current.appleId,
      decryptSecret(current.encryptedPassword),
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

    const rangeStart = new Date(now - 45 * 24 * 60 * 60 * 1000);
    const rangeEnd = new Date(now + 370 * 24 * 60 * 60 * 1000);
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
      for (const object of objects) {
        if (!object.data || !object.url) continue;
        try {
          const parsed = parseIcalEvent(object.data);
          await db
            .insert(calendarEvents)
            .values({
              id: randomUUID(),
              calendarId: localCalendar.id,
              href: object.url,
              etag: object.etag,
              rawIcal: object.data,
              ...parsed,
            })
            .onConflictDoUpdate({
              target: [calendarEvents.calendarId, calendarEvents.href],
              set: {
                etag: object.etag,
                rawIcal: object.data,
                ...parsed,
                updatedAt: new Date(),
              },
            });
          count += 1;
        } catch {
          // Ignore non-event calendar objects without leaking calendar content.
        }
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
    .where(eq(calendarConnections.householdId, householdId));
}

export async function getCalendarClientForHousehold(householdId: string) {
  const result = await db
    .select()
    .from(calendarConnections)
    .where(eq(calendarConnections.householdId, householdId))
    .limit(1);
  if (!result[0]) throw new Error("iCloud is not connected.");
  const client = makeClient(
    result[0].appleId,
    decryptSecret(result[0].encryptedPassword),
  );
  await client.login();
  return { client, connection: result[0] };
}
