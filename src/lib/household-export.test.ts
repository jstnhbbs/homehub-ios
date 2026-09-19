import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "beacon-export-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;

type Db = typeof import("@/db/client");
type Schema = typeof import("@/db/schema");
type Exporter = typeof import("./household-export");

let client: Db;
let schema: Schema;
let exporter: Exporter;

beforeAll(async () => {
  client = await import("@/db/client");
  schema = await import("@/db/schema");
  exporter = await import("./household-export");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(client.db, { migrationsFolder: "drizzle" });

  const { db } = client;
  const now = new Date();
  for (const [id, name] of [
    ["h1", "Test Family"],
    ["h2", "Other Family"],
  ]) {
    await db.insert(schema.households).values({
      id,
      name,
      inviteCode: `INV-${id}`,
      guestInviteCode: `GUEST-${id}`,
    });
  }
  await db.insert(schema.users).values({
    id: "u1",
    name: "Pat Parent",
    email: "pat@example.com",
    createdAt: now,
    updatedAt: now,
  });
  await db
    .insert(schema.householdMembers)
    .values({ householdId: "h1", userId: "u1", role: "owner" });
  await db
    .insert(schema.profiles)
    .values({ id: "p1", householdId: "h1", name: "Kid" });
  await db
    .insert(schema.routines)
    .values({ id: "r1", householdId: "h1", name: "Morning", period: "morning" });
  await db
    .insert(schema.routineSteps)
    .values({ id: "s1", routineId: "r1", label: "Brush teeth" });
  await db
    .insert(schema.routineCompletions)
    .values({ stepId: "s1", localDate: "2026-09-18" });
  await db
    .insert(schema.recipes)
    .values({
      id: "rec1",
      householdId: "h1",
      title: "Pancakes",
      ingredients: JSON.stringify(["1 cup flour", "2 eggs"]),
      directions: JSON.stringify(["Mix", "Cook"]),
    });
  await db.insert(schema.householdNotes).values({
    id: "n1",
    householdId: "h1",
    createdByUserId: "u1",
    title: "Remember milk",
  });
  await db
    .insert(schema.groceryItems)
    .values({ id: "g1", householdId: "h1", title: "Bread" });
  // Data belonging to another household must never appear.
  await db
    .insert(schema.groceryItems)
    .values({ id: "g2", householdId: "h2", title: "Someone else's bread" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("buildHouseholdExport", () => {
  it("includes the household's data, nested and readable", async () => {
    const data = await exporter.buildHouseholdExport("h1");

    expect(data.format).toBe("beacon-household-export");
    expect(data.household?.name).toBe("Test Family");
    expect(data.profiles.map((p) => p.name)).toEqual(["Kid"]);
    expect(data.routines[0].steps.map((s) => s.label)).toEqual(["Brush teeth"]);
    expect(data.routineCompletions).toHaveLength(1);
    expect(data.recipes[0].ingredients).toEqual(["1 cup flour", "2 eggs"]);
    expect(data.recipes[0].directions).toEqual(["Mix", "Cook"]);
    expect(data.notes.map((n) => n.title)).toEqual(["Remember milk"]);
    expect(data.members).toMatchObject([{ name: "Pat Parent", role: "owner" }]);
  });

  it("never includes another household's rows", async () => {
    const data = await exporter.buildHouseholdExport("h1");
    expect(data.groceryItems.map((g) => g.title)).toEqual(["Bread"]);
    expect(JSON.stringify(data)).not.toContain("Someone else");
  });

  it("leaves out invite codes, emails, and author ids", async () => {
    const text = JSON.stringify(await exporter.buildHouseholdExport("h1"));
    expect(text).not.toContain("INV-h1");
    expect(text).not.toContain("GUEST-h1");
    expect(text).not.toContain("pat@example.com");
    expect(text).not.toContain("createdByUserId");
    expect(text).not.toContain("householdId");
  });

  it("returns empty collections for a household with no data", async () => {
    const data = await exporter.buildHouseholdExport("h2");
    expect(data.profiles).toEqual([]);
    expect(data.routines).toEqual([]);
    expect(data.recipes).toEqual([]);
    expect(data.groceryItems).toHaveLength(1);
  });
});
