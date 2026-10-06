import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-chores-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "parent" | "guest";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Item = {
  id: string;
  title: string;
  dueDate: string | null;
  dueTime: string | null;
  repeatUnit: string;
  repeatInterval: number;
  periodKey: string;
  completed: boolean;
  dueToday: boolean;
  overdue: boolean;
  nextDueDate: string | null;
  cadence: string;
};

const password = "correct-horse-battery";
const cookies: Partial<Record<Role, string>> = {};

async function call(role: Role, route: string, method: string, body?: unknown, params: Record<string, string> = {}) {
  request.headers = new Headers({ cookie: cookies[role]! });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}?scope=all`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" || method === "DELETE" ? undefined : JSON.stringify(body ?? {}),
    }),
    { params: Promise.resolve(params) },
  );
  const text = await response.text();
  return { status: response.status, json: JSON.parse(text) };
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B" });
  for (const role of ["parent", "guest"] as const) {
    const email = `${role}@example.com`;
    const created = await auth.api.signUpEmail({ body: { name: role, email, password } });
    const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
    cookies[role] = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role });
  }
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("chore due dates", () => {
  it("has no due date by default", async () => {
    const created = await call("parent", "chores", "POST", { title: "Feed the dog", cadence: "daily" });
    expect(created.status).toBe(201);
    expect(created.json.dueDate).toBeNull();
  });

  it("saves a due date on a chore that does not repeat", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Book report",
      repeatUnit: "none",
      dueDate: "2099-01-05",
    });
    expect(created.status).toBe(201);
    expect(created.json.dueDate).toBe("2099-01-05");

    const list = await call("guest", "chores", "GET");
    const listed = (list.json as Item[]).find((item) => item.id === created.json.id)!;
    expect(listed.dueDate).toBe("2099-01-05");
    expect(listed.overdue).toBe(false);
    expect(listed.dueToday).toBe(false);
    expect(listed.nextDueDate).toBe("2099-01-05");
  });

  it("flags a past due date as overdue until it's completed", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Permission slip",
      repeatUnit: "none",
      dueDate: "2000-01-01",
    });

    const list = await call("guest", "chores", "GET");
    const listed = (list.json as Item[]).find((item) => item.id === created.json.id)!;
    expect(listed.overdue).toBe(true);

    expect(listed.periodKey).toBe("once");

    await call("guest", "chores/toggle", "POST", { choreId: created.json.id, periodKey: "once" });
    const afterToggle = await call("guest", "chores", "GET");
    const toggled = (afterToggle.json as Item[]).find((item) => item.id === created.json.id)!;
    expect(toggled.overdue).toBe(false);
  });

  it("clears a due date when the edit omits it", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Science fair board",
      cadence: "daily",
      dueDate: "2099-02-01",
    });

    const updated = await call("parent", "chores/[id]", "PATCH", { title: "Science fair board", cadence: "daily" }, { id: created.json.id });
    expect(updated.status).toBe(200);
    expect(updated.json.dueDate).toBeNull();
  });

  it("rejects a malformed due date", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Bad date",
      cadence: "daily",
      dueDate: "not-a-date",
    });
    expect(created.status).toBe(400);
  });
});

describe("chore repeats", () => {
  const find = async (id: string) =>
    ((await call("guest", "chores", "GET")).json as Item[]).find((item) => item.id === id)!;

  it("keeps working for apps that send only a cadence", async () => {
    const created = await call("parent", "chores", "POST", { title: "Old app", cadence: "weekly", weekDay: "3" });
    expect(created.status).toBe(201);
    expect(created.json).toMatchObject({ cadence: "weekly", repeatUnit: "week", repeatInterval: 1, days: "3" });
  });

  it("repeats every two weeks from a date", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Change filters",
      cadence: "weekly",
      repeatUnit: "week",
      repeatInterval: 2,
      weekDay: "3",
      dueDate: "2026-10-07",
      dueTime: "09:00",
    });
    expect(created.status).toBe(201);
    expect(created.json).toMatchObject({ repeatUnit: "week", repeatInterval: 2, dueTime: "09:00" });
    const listed = await find(created.json.id);
    expect(listed.dueTime).toBe("09:00");
    // The listing is for today, so only the shape is checked here; the dates are in chores.test.ts.
    expect(listed.periodKey).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it("runs a one-off with no date until it is done", async () => {
    const created = await call("parent", "chores", "POST", { title: "Fix the gate", repeatUnit: "none" });
    expect(created.status).toBe(201);
    const open = await find(created.json.id);
    expect(open).toMatchObject({ repeatUnit: "none", dueToday: true, completed: false, periodKey: "once" });

    await call("guest", "chores/toggle", "POST", { choreId: created.json.id, periodKey: "once", completed: true });
    expect(await find(created.json.id)).toMatchObject({ completed: true, dueToday: true });
  });

  it("changes a chore from repeating to a one-off, and back", async () => {
    const created = await call("parent", "chores", "POST", { title: "Switch", repeatUnit: "day" });
    const once = await call("parent", "chores/[id]", "PATCH", { title: "Switch", repeatUnit: "none", dueDate: "2099-03-01" }, { id: created.json.id });
    expect(once.json).toMatchObject({ repeatUnit: "none", cadence: "weekly", dueDate: "2099-03-01" });
    const daily = await call("parent", "chores/[id]", "PATCH", { title: "Switch", repeatUnit: "day" }, { id: created.json.id });
    expect(daily.json).toMatchObject({ repeatUnit: "day", cadence: "daily", dueDate: null });
  });

  it.each([
    ["monthly with no date", { repeatUnit: "month" }],
    ["every 3 days with no date", { repeatUnit: "day", repeatInterval: 3 }],
    ["a time on a one-off with no date", { repeatUnit: "none", dueTime: "08:00" }],
    ["a time that is not a time", { repeatUnit: "day", dueTime: "25:99" }],
    ["a date that is not a date", { repeatUnit: "none", dueDate: "2026-02-30" }],
    ["no repeat or cadence at all", {}],
    ["an interval of zero", { repeatUnit: "week", repeatInterval: 0, dueDate: "2026-10-07" }],
  ])("refuses %s", async (_label, body) => {
    const created = await call("parent", "chores", "POST", { title: "Nope", ...body });
    expect(created.status).toBe(400);
  });

  it("checks off a repeating chore by date and refuses a one-off's key", async () => {
    const created = await call("parent", "chores", "POST", { title: "By date", repeatUnit: "month", dueDate: "2026-01-15" });
    const ok = await call("guest", "chores/toggle", "POST", { choreId: created.json.id, periodKey: "2026-10-15", completed: true });
    expect(ok.status).toBe(200);
    const bad = await call("guest", "chores/toggle", "POST", { choreId: created.json.id, periodKey: "once", completed: true });
    expect(bad.status).toBe(400);
  });
});

describe("who a chore can be given to", () => {
  it("tells the app each profile's role, so it can leave out other adults", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    // Signed-in members already have a profile each, made when they first used the household.
    await db.insert(schema.profiles).values([
      { id: "p-kid", householdId: "h1", name: "Ava", profileType: "child", color: "#d87861" },
      { id: "p-gran", householdId: "h1", name: "Grandma", profileType: "adult", color: "#d87861" },
    ]);
    const list = await call("guest", "profiles", "GET");
    const roles = Object.fromEntries(
      (list.json as { name: string; memberRole: string | null }[]).map((p) => [p.name, p.memberRole]),
    );
    expect(roles).toMatchObject({ parent: "parent", guest: "guest", Ava: null, Grandma: null });
  });
});
