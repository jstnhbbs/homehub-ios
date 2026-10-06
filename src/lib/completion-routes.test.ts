import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-completion-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Who = "parent" | "other";

const password = "correct-horse-battery";
const cookies: Record<string, string> = {};
const ids = {
  step: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  daily: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
  weekly: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  kid: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
};
const today = "2026-10-04";
const week = "2026-W40";
const userIds: Record<string, string> = {};

async function post(who: Who, route: string, body: unknown) {
  request.headers = new Headers({ cookie: cookies[who] });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule.POST(
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    }),
    { params: Promise.resolve({}) },
  );
  return { status: response.status, json: (await response.json()) as Record<string, unknown> };
}

async function count(table: "routine" | "chore" | "snack") {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const target = { routine: schema.routineCompletions, chore: schema.choreCompletions, snack: schema.snackCompletions }[table];
  return (await db.select().from(target)).length;
}

async function completers(table: "routine" | "chore") {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const target = table === "routine" ? schema.routineCompletions : schema.choreCompletions;
  return (await db.select({ by: target.completedBy }).from(target)).map((row) => row.by);
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B", snackOptions: "Apples\nYogurt" });
  await db.insert(schema.profiles).values({ id: ids.kid, householdId: "h1", name: "Ava", profileType: "child", color: "#d87861" });
  await db.insert(schema.routines).values({ id: "r1", householdId: "h1", name: "Morning", period: "morning" });
  await db.insert(schema.routineSteps).values({ id: ids.step, routineId: "r1", label: "Brush teeth" });
  await db.insert(schema.chores).values([
    { id: ids.daily, householdId: "h1", title: "Feed dog", cadence: "daily" },
    { id: ids.weekly, householdId: "h1", title: "Mow", cadence: "weekly", repeatUnit: "week" },
  ]);
  for (const who of ["parent", "other"] as const) {
    const email = `${who}@example.com`;
    const created = await auth.api.signUpEmail({ body: { name: who, email, password } });
    const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
    cookies[who] = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    userIds[who] = created.user.id;
    await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role: "parent" });
  }
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

const cases = [
  {
    name: "routine step",
    route: "routines/toggle-step",
    table: "routine" as const,
    body: () => ({ stepId: ids.step, localDate: today }),
  },
  {
    name: "chore",
    route: "chores/toggle",
    table: "chore" as const,
    body: () => ({ choreId: ids.daily, periodKey: today }),
  },
  {
    name: "snack",
    route: "snacks/toggle",
    table: "snack" as const,
    body: () => ({ localDate: today, snackLabel: "Apples", profileId: ids.kid }),
  },
];

describe.each(cases)("checking off a $name", ({ route, table, body }) => {
  it("sets it done when asked to, however many times the request arrives", async () => {
    const first = await post("parent", route, { ...body(), completed: true });
    expect(first.status).toBe(200);
    expect(first.json.completed).toBe(true);
    const before = await count(table);

    // A retry after a dropped connection, or a second phone tapping the same item.
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const again = await post("other", route, { ...body(), completed: true });
      expect(again.json.completed).toBe(true);
    }
    expect(await count(table)).toBe(before);
  });

  it("sets it not-done when asked to, and stays that way when repeated", async () => {
    const undone = await post("parent", route, { ...body(), completed: false });
    expect(undone.status).toBe(200);
    expect(undone.json.completed).toBe(false);
    const after = await count(table);

    const again = await post("other", route, { ...body(), completed: false });
    expect(again.json.completed).toBe(false);
    expect(await count(table)).toBe(after);
  });

  it("still flips it for an app that does not say which state it wants", async () => {
    const start = await count(table);
    const flipped = await post("parent", route, body());
    expect(flipped.json.completed).toBe(true);
    expect(await count(table)).toBe(start + 1);
    const back = await post("parent", route, body());
    expect(back.json.completed).toBe(false);
    expect(await count(table)).toBe(start);
  });

  it("two simultaneous requests for the same state end in that state", async () => {
    await post("parent", route, { ...body(), completed: false });
    const baseline = await count(table);
    const results = await Promise.all([
      post("parent", route, { ...body(), completed: true }),
      post("other", route, { ...body(), completed: true }),
    ]);
    expect(results.map((result) => result.status)).toEqual([200, 200]);
    // Exactly one completion, not zero (the flip-flop) and not an error from a clash.
    expect(await count(table)).toBe(baseline + 1);
    await post("parent", route, { ...body(), completed: false });
  });
});

describe("who gets the credit", () => {
  it("keeps the first person to check an item off when someone else repeats it", async () => {
    await post("parent", "chores/toggle", { choreId: ids.daily, periodKey: today, completed: true });
    await post("other", "chores/toggle", { choreId: ids.daily, periodKey: today, completed: true });
    expect(await completers("chore")).toEqual([userIds.parent]);
    await post("parent", "chores/toggle", { choreId: ids.daily, periodKey: today, completed: false });

    await post("other", "routines/toggle-step", { stepId: ids.step, localDate: today, completed: true });
    await post("parent", "routines/toggle-step", { stepId: ids.step, localDate: today, completed: true });
    expect(await completers("routine")).toEqual([userIds.other]);
    await post("other", "routines/toggle-step", { stepId: ids.step, localDate: today, completed: false });
  });
});

describe("chore periods", () => {
  it.each([
    ["a daily chore", () => ids.daily, today, 200],
    ["a weekly chore by week", () => ids.weekly, week, 200],
  ])("accepts %s", async (_label, choreId, periodKey, status) => {
    const result = await post("parent", "chores/toggle", { choreId: choreId(), periodKey, completed: true });
    expect(result.status).toBe(status);
    await post("parent", "chores/toggle", { choreId: choreId(), periodKey, completed: false });
  });

  it.each([
    ["a daily chore with a week key", () => ids.daily, week],
    ["a weekly chore with a date", () => ids.weekly, today],
    ["a made-up key", () => ids.daily, "whenever"],
    ["a week that does not exist", () => ids.weekly, "2026-W99"],
    ["a very long key", () => ids.daily, "x".repeat(500)],
    ["an impossible shape", () => ids.daily, "2026-10-04; drop table chores"],
  ])("refuses %s", async (_label, choreId, periodKey) => {
    const before = await count("chore");
    const result = await post("parent", "chores/toggle", { choreId: choreId(), periodKey, completed: true });
    expect(result.status).toBe(400);
    expect(await count("chore")).toBe(before);
  });
});
