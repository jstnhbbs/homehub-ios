import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "beacon-streaks-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;

type Store = typeof import("./streak-store");
let store: Store;
let db: typeof import("@/db/client").db;
let schema: typeof import("@/db/schema");

const today = "2026-09-18";
const timezone = "America/Chicago";

async function addRoutine(
  id: string,
  profileId: string | null,
  householdId = "h1",
  createdAt = new Date("2026-08-01T12:00:00Z"),
) {
  await db.insert(schema.routines).values({
    id,
    householdId,
    profileId,
    name: id,
    period: "morning",
    createdAt,
    updatedAt: createdAt,
  });
}

async function addStep(id: string, routineId: string, createdAt: Date | null) {
  await db.insert(schema.routineSteps).values({ id, routineId, label: id, createdAt });
}

async function complete(stepId: string, dates: string[]) {
  for (const localDate of dates) {
    await db.insert(schema.routineCompletions).values({ stepId, localDate });
  }
}

function range(from: number, to: number) {
  return Array.from({ length: to - from + 1 }, (_, i) => `2026-09-${String(from + i).padStart(2, "0")}`);
}

beforeAll(async () => {
  ({ db } = await import("@/db/client"));
  schema = await import("@/db/schema");
  store = await import("./streak-store");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B" });
  await db.insert(schema.households).values({ id: "h2", name: "Other", inviteCode: "C", guestInviteCode: "D" });
  await db.insert(schema.profiles).values([
    { id: "kid1", householdId: "h1", name: "Kid One" },
    { id: "kid2", householdId: "h1", name: "Kid Two" },
  ]);

  // Kid one: two new-style steps, both done for the last five days.
  await addRoutine("r1", "kid1");
  await addStep("s1", "r1", new Date("2026-08-01T12:00:00Z"));
  await addStep("s2", "r1", new Date("2026-08-01T12:00:00Z"));
  await complete("s1", range(14, 18));
  await complete("s2", range(14, 18));

  // Kid two: a legacy step (no created_at) first completed on the 10th, then done through today.
  await addRoutine("r2", "kid2");
  await addStep("s3", "r2", null);
  await complete("s3", range(10, 18));

  // A routine shared by the household, with one step done yesterday only.
  await addRoutine("r3", null);
  await addStep("s4", "r3", new Date("2026-08-01T12:00:00Z"));
  await complete("s4", ["2026-09-17"]);

  // Another household's data must never leak in.
  await addRoutine("other", null, "h2");
  await addStep("s9", "other", new Date("2026-08-01T12:00:00Z"));
  await complete("s9", range(1, 18));
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("loadRoutineStreaks", () => {
  it("computes a streak per profile and one for household-wide routines", async () => {
    const streaks = await store.loadRoutineStreaks("h1", timezone, today);
    const byProfile = new Map(streaks.map((streak) => [streak.profileId, streak]));

    expect(byProfile.size).toBe(3);
    expect(byProfile.get("kid1")).toMatchObject({ current: 5, best: 5, completedToday: true });
    expect(byProfile.get(null)).toMatchObject({ current: 1, completedToday: false, todayPending: true });
  });

  it("starts a legacy step at its first completion instead of failing earlier days", async () => {
    const streaks = await store.loadRoutineStreaks("h1", timezone, today);
    const kid2 = streaks.find((streak) => streak.profileId === "kid2");
    expect(kid2).toMatchObject({ current: 9, best: 9, completedToday: true });
  });

  it("does not include another household's routines", async () => {
    const streaks = await store.loadRoutineStreaks("h1", timezone, today);
    expect(streaks.every((streak) => ["kid1", "kid2", null].includes(streak.profileId))).toBe(true);
    const shared = streaks.find((streak) => streak.profileId === null);
    // The other household's step was done every day; h1's shared step was done only yesterday.
    expect(shared?.current).toBe(1);
  });

  it("returns nothing for a household without routines", async () => {
    expect(await store.loadRoutineStreaks("nobody", timezone, today)).toEqual([]);
  });
});
