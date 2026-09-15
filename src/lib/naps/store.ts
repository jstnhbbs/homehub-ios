import { randomUUID } from "node:crypto";
import { and, asc, eq, gte, isNull, lte, ne, or } from "drizzle-orm";
import { format } from "date-fns";
import { fromZonedTime } from "date-fns-tz";
import { db } from "@/db/client";
import { napLogs, profiles, type SleepKind } from "@/db/schema";
import { parseWeekStartsOn } from "@/lib/calendar/week-start";
import { localDateIn, weekDates } from "@/lib/dates";
import { addLocalDays } from "@/lib/naps/datetime";
import { sleepOverlapsLocalDate } from "@/lib/naps/overlap";
import type { getCurrentHousehold } from "@/lib/household";

type Household = NonNullable<Awaited<ReturnType<typeof getCurrentHousehold>>>;

export type NapLogRecord = {
  id: string;
  profileId: string;
  kind: SleepKind;
  localDate: string;
  startedAt: Date;
  endedAt: Date | null;
  notes: string | null;
};

function mapNap(row: typeof napLogs.$inferSelect): NapLogRecord {
  return {
    id: row.id,
    profileId: row.profileId,
    kind: row.kind,
    localDate: row.localDate,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    notes: row.notes,
  };
}

function validateSleepTimes(startedAt: Date, endedAt: Date | null) {
  if (endedAt && endedAt.getTime() <= startedAt.getTime()) {
    throw new Error("Wake time must be after sleep time.");
  }
}

async function assertChildProfile(household: Household, profileId: string) {
  const child = await db
    .select({ id: profiles.id })
    .from(profiles)
    .where(
      and(
        eq(profiles.id, profileId),
        eq(profiles.householdId, household.id),
        eq(profiles.profileType, "child"),
      ),
    )
    .limit(1);
  if (!child[0]) throw new Error("Child profile not found.");
}

async function assertNoActiveSleep(
  household: Household,
  profileId: string,
  excludeSleepId?: string,
) {
  const conditions = [
    eq(napLogs.householdId, household.id),
    eq(napLogs.profileId, profileId),
    isNull(napLogs.endedAt),
  ];
  if (excludeSleepId) {
    conditions.push(ne(napLogs.id, excludeSleepId));
  }

  const active = await db
    .select({ id: napLogs.id })
    .from(napLogs)
    .where(and(...conditions))
    .limit(1);
  if (active[0]) throw new Error("This child already has sleep in progress.");
}

export async function fetchChildProfiles(householdId: string) {
  return db
    .select()
    .from(profiles)
    .where(
      and(
        eq(profiles.householdId, householdId),
        eq(profiles.profileType, "child"),
      ),
    )
    .orderBy(asc(profiles.sortOrder));
}

export async function startNap(household: Household, profileId: string) {
  await assertChildProfile(household, profileId);
  await assertNoActiveSleep(household, profileId);

  const startedAt = new Date();
  const id = randomUUID();
  await db.insert(napLogs).values({
    id,
    householdId: household.id,
    profileId,
    kind: "nap",
    localDate: localDateIn(household.timezone, startedAt),
    startedAt,
  });

  return id;
}

export async function fetchSleepLogsInRange(
  household: Household,
  startLocalDate: string,
  endLocalDate: string,
) {
  const queryStart = addLocalDays(startLocalDate, household.timezone, -1);
  const rows = await db
    .select()
    .from(napLogs)
    .where(
      and(
        eq(napLogs.householdId, household.id),
        or(
          and(gte(napLogs.localDate, queryStart), lte(napLogs.localDate, endLocalDate)),
          isNull(napLogs.endedAt),
        ),
      ),
    )
    .orderBy(asc(napLogs.startedAt));

  return rows.map(mapNap);
}

export async function fetchSleepForDate(household: Household, localDate: string) {
  const queryStart = addLocalDays(localDate, household.timezone, -1);
  const rows = await db
    .select()
    .from(napLogs)
    .where(
      and(
        eq(napLogs.householdId, household.id),
        or(
          and(gte(napLogs.localDate, queryStart), lte(napLogs.localDate, localDate)),
          isNull(napLogs.endedAt),
        ),
      ),
    )
    .orderBy(asc(napLogs.startedAt));

  const now = new Date();
  return rows
    .map(mapNap)
    .filter(
      (log) =>
        sleepOverlapsLocalDate(log, localDate, household.timezone, now) ||
        (log.kind === "nap" && !log.endedAt),
    );
}

export async function fetchNapPageData(household: Household) {
  const localDate = localDateIn(household.timezone);
  const weekStartsOn = parseWeekStartsOn(household.weekStartsOn);
  const weekDays = weekDates(
    fromZonedTime(`${localDate}T12:00:00`, household.timezone),
    weekStartsOn,
  );
  const weekDatesList = weekDays.map((day) => format(day, "yyyy-MM-dd"));
  const weekStart = weekDatesList[0];
  const weekEnd = weekDatesList[6];

  const [childProfiles, todayLogs, weekLogs] = await Promise.all([
    fetchChildProfiles(household.id),
    fetchSleepForDate(household, localDate),
    fetchSleepLogsInRange(household, weekStart, weekEnd),
  ]);

  const naps = todayLogs.filter((log) => log.kind === "nap" || !log.endedAt);

  return {
    localDate,
    weekDates: weekDatesList,
    childProfiles,
    naps,
    weekLogs,
  };
}

export async function fetchTodayNaps(household: Household) {
  const localDate = localDateIn(household.timezone);
  const [childProfiles, logs] = await Promise.all([
    fetchChildProfiles(household.id),
    fetchSleepForDate(household, localDate),
  ]);

  return {
    localDate,
    childProfiles,
    naps: logs.filter((log) => log.kind === "nap" || !log.endedAt),
    logs,
  };
}

export async function createManualNap(
  household: Household,
  profileId: string,
  startedAt: Date,
  endedAt: Date | null,
) {
  await assertChildProfile(household, profileId);
  validateSleepTimes(startedAt, endedAt);
  if (!endedAt) {
    await assertNoActiveSleep(household, profileId);
  }

  const id = randomUUID();
  await db.insert(napLogs).values({
    id,
    householdId: household.id,
    profileId,
    kind: "nap",
    localDate: localDateIn(household.timezone, startedAt),
    startedAt,
    endedAt,
  });

  return id;
}

export async function startNightSleep(household: Household, profileId: string) {
  await assertChildProfile(household, profileId);
  await assertNoActiveSleep(household, profileId);

  const startedAt = new Date();
  const id = randomUUID();
  await db.insert(napLogs).values({
    id,
    householdId: household.id,
    profileId,
    kind: "night",
    localDate: localDateIn(household.timezone, startedAt),
    startedAt,
  });

  return id;
}

export async function createNightSleep(
  household: Household,
  profileId: string,
  fellAsleepAt: Date,
  wokeUpAt: Date | null,
) {
  await assertChildProfile(household, profileId);
  validateSleepTimes(fellAsleepAt, wokeUpAt);
  if (!wokeUpAt) {
    await assertNoActiveSleep(household, profileId);
  }

  const id = randomUUID();
  await db.insert(napLogs).values({
    id,
    householdId: household.id,
    profileId,
    kind: "night",
    localDate: localDateIn(
      household.timezone,
      wokeUpAt ?? fellAsleepAt,
    ),
    startedAt: fellAsleepAt,
    endedAt: wokeUpAt,
  });

  return id;
}

export async function updateNapTimes(
  household: Household,
  napId: string,
  startedAt: Date,
  endedAt: Date | null,
) {
  validateSleepTimes(startedAt, endedAt);

  const existing = await db
    .select()
    .from(napLogs)
    .where(and(eq(napLogs.id, napId), eq(napLogs.householdId, household.id)))
    .limit(1);
  if (!existing[0]) throw new Error("Sleep entry not found.");

  if (!endedAt) {
    await assertNoActiveSleep(household, existing[0].profileId, napId);
  }

  const anchorDate =
    existing[0].kind === "night" && endedAt ? endedAt : startedAt;

  const updated = await db
    .update(napLogs)
    .set({
      startedAt,
      endedAt,
      localDate: localDateIn(household.timezone, anchorDate),
      updatedAt: new Date(),
    })
    .where(and(eq(napLogs.id, napId), eq(napLogs.householdId, household.id)))
    .returning({ id: napLogs.id });
  if (!updated[0]) throw new Error("Sleep entry not found.");
}

export async function endNap(
  household: Household,
  napId: string,
  endedAt: Date = new Date(),
) {
  const existing = await db
    .select({ startedAt: napLogs.startedAt, kind: napLogs.kind })
    .from(napLogs)
    .where(
      and(
        eq(napLogs.id, napId),
        eq(napLogs.householdId, household.id),
        isNull(napLogs.endedAt),
      ),
    )
    .limit(1);
  if (!existing[0]) throw new Error("Active sleep not found.");
  validateSleepTimes(existing[0].startedAt, endedAt);

  const updated = await db
    .update(napLogs)
    .set({
      endedAt,
      ...(existing[0].kind === "night"
        ? { localDate: localDateIn(household.timezone, endedAt) }
        : {}),
      updatedAt: new Date(),
    })
    .where(
      and(
        eq(napLogs.id, napId),
        eq(napLogs.householdId, household.id),
        isNull(napLogs.endedAt),
      ),
    )
    .returning({ id: napLogs.id });
  if (!updated[0]) throw new Error("Active sleep not found.");
}

export async function endNapForProfile(household: Household, profileId: string) {
  const active = await db
    .select({ id: napLogs.id })
    .from(napLogs)
    .where(
      and(
        eq(napLogs.householdId, household.id),
        eq(napLogs.profileId, profileId),
        isNull(napLogs.endedAt),
      ),
    )
    .limit(1);
  if (!active[0]) throw new Error("Active sleep not found.");
  await endNap(household, active[0].id);
}

export async function deleteNap(household: Household, napId: string) {
  const deleted = await db
    .delete(napLogs)
    .where(and(eq(napLogs.id, napId), eq(napLogs.householdId, household.id)))
    .returning({ id: napLogs.id });
  if (!deleted[0]) throw new Error("Sleep entry not found.");
}

export function serializeNap(nap: NapLogRecord) {
  return {
    id: nap.id,
    profileId: nap.profileId,
    kind: nap.kind,
    localDate: nap.localDate,
    startedAt: nap.startedAt.toISOString(),
    endedAt: nap.endedAt?.toISOString() ?? null,
    notes: nap.notes,
  };
}

// Backward-compatible aliases used by older imports.
export const fetchNapsForDate = fetchSleepForDate;
export const fetchNapsInRange = fetchSleepLogsInRange;
