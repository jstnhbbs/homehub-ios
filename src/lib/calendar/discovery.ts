import { randomUUID } from "node:crypto";
import { eq, inArray } from "drizzle-orm";
import { db } from "@/db/client";
import { calendars } from "@/db/schema";

export type DiscoveredCalendar = {
  url: string;
  displayName: string;
  color: string;
  syncToken?: string | null;
  ctag?: string | null;
};

export async function upsertDiscoveredCalendars(
  connectionId: string,
  discovered: DiscoveredCalendar[],
  options: { enableNewCalendars: boolean },
) {
  await db.transaction(async (tx) => {
    for (const calendar of discovered) {
      await tx
        .insert(calendars)
        .values({
          id: randomUUID(),
          connectionId,
          enabled: options.enableNewCalendars,
          url: calendar.url,
          displayName: calendar.displayName,
          color: calendar.color,
          syncToken: calendar.syncToken ?? null,
          ctag: calendar.ctag ?? null,
        })
        .onConflictDoUpdate({
          target: [calendars.connectionId, calendars.url],
          set: {
            displayName: calendar.displayName,
            color: calendar.color,
            syncToken: calendar.syncToken ?? null,
            ctag: calendar.ctag ?? null,
          },
        });
    }

    const existing = await tx
      .select({ id: calendars.id, url: calendars.url })
      .from(calendars)
      .where(eq(calendars.connectionId, connectionId));
    const remoteUrls = new Set(discovered.map((calendar) => calendar.url));
    const staleIds = existing
      .filter((calendar) => !remoteUrls.has(calendar.url))
      .map((calendar) => calendar.id);
    for (let index = 0; index < staleIds.length; index += 200) {
      await tx
        .delete(calendars)
        .where(inArray(calendars.id, staleIds.slice(index, index + 200)));
    }
  });
}
