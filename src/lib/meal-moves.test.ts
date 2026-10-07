import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { eq, sql } from "drizzle-orm";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/mobile/http", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/mobile/http")>()),
  requireMobileParentHousehold: async () => ({ id: "h1" }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-meal-moves-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Slot = { localDate: string; slot: "breakfast" | "lunch" | "dinner" | "snack" };
const source: Slot = { localDate: "2026-10-07", slot: "dinner" };
const target: Slot = { localDate: "2026-10-08", slot: "lunch" };

async function move(from = source, to = target) {
  const { POST } = await import("@/app/api/mobile/v1/meals/move/route");
  return POST(new Request("http://localhost:3000/api/mobile/v1/meals/move", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ source: from, target: to }),
  }));
}

async function rows() {
  const { db } = await import("@/db/client");
  const { meals } = await import("@/db/schema");
  return db.select().from(meals).orderBy(meals.id);
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const { households, recipes } = await import("@/db/schema");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  await db.insert(households).values([
    { id: "h1", name: "Family", inviteCode: "PARENT1", guestInviteCode: "GUEST1" },
    { id: "h2", name: "Other", inviteCode: "PARENT2", guestInviteCode: "GUEST2" },
  ]);
  await db.insert(recipes).values({ id: "recipe", householdId: "h1", title: "Pasta recipe" });
});

beforeEach(async () => {
  const { db } = await import("@/db/client");
  const { meals } = await import("@/db/schema");
  await db.delete(meals);
  await db.insert(meals).values({
    id: "a", householdId: "h1", ...source, title: "Pasta", notes: "No cheese", recipeId: "recipe",
    createdAt: new Date("2026-10-01T12:00:00Z"),
  });
});

afterAll(async () => {
  const { turso } = await import("@/db/client");
  turso.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("atomic meal moves", () => {
  it("moves to an empty slot and preserves the meal's identity and metadata", async () => {
    const [before] = await rows();
    const response = await move();
    expect(response.status).toBe(200);
    const [after] = await rows();
    expect(after).toMatchObject({ ...before, ...target, updatedAt: expect.any(Date) });
    expect((await response.json()).meals).toHaveLength(1);
  });

  it("swaps both occupied slots without losing their notes or creation dates", async () => {
    const { db } = await import("@/db/client");
    const { meals } = await import("@/db/schema");
    await db.insert(meals).values({ id: "b", householdId: "h1", ...target, title: "Soup", notes: "Pack bread" });
    const before = await rows();
    expect((await move()).status).toBe(200);
    const after = await rows();
    expect(after[0]).toMatchObject({ ...before[0], ...target, updatedAt: expect.any(Date) });
    expect(after[1]).toMatchObject({ ...before[1], ...source, updatedAt: expect.any(Date) });
  });

  it("does not touch another household's slots", async () => {
    const { db } = await import("@/db/client");
    const { meals } = await import("@/db/schema");
    await db.insert(meals).values({ id: "other", householdId: "h2", ...target, title: "Private meal" });
    const other = (await rows()).find((row) => row.id === "other");
    expect((await move()).status).toBe(200);
    expect((await rows()).find((row) => row.id === "other")).toEqual(other);
  });

  it("rejects a missing source without clearing the destination", async () => {
    const before = await rows();
    expect((await move(target, source)).status).toBe(400);
    expect(await rows()).toEqual(before);
  });

  it("rejects moving to the same slot", async () => {
    const before = await rows();
    expect((await move(source, source)).status).toBe(400);
    expect(await rows()).toEqual(before);
  });

  it("rolls back both deleted slots when writing the replacements fails", async () => {
    const { db } = await import("@/db/client");
    const { meals } = await import("@/db/schema");
    await db.insert(meals).values({ id: "b", householdId: "h1", ...target, title: "Soup" });
    const before = await rows();
    await db.run(sql`CREATE TRIGGER fail_meal_move BEFORE INSERT ON meals
      WHEN NEW.local_date = '2026-10-08'
      BEGIN SELECT RAISE(ABORT, 'forced insert failure'); END`);
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      expect((await move()).status).toBe(500);
      expect(await rows()).toEqual(before);
      expect(await db.select().from(meals).where(eq(meals.householdId, "h1"))).toHaveLength(2);
    } finally {
      await db.run(sql`DROP TRIGGER fail_meal_move`);
      log.mockRestore();
    }
  });
});
