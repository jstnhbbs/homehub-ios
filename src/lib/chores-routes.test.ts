import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import type { InStatement } from "@libsql/client";
import { eq } from "drizzle-orm";
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

async function call(role: Role, route: string, method: string, body?: unknown, params: Record<string, string> = {}, query = "scope=all") {
  request.headers = new Headers({ cookie: cookies[role]! });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}?${query}`, {
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

describe("bounded chore completion reads", () => {
  it("reads only the requested periods while preserving old one-off completions", async () => {
    const { db, turso } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const localDate = "2026-10-07";
    const ids = ["history-daily", "history-weekly", "history-monthly", "history-once", "history-open"];
    await db.insert(schema.chores).values([
      { id: ids[0], householdId: "h1", title: "Daily", repeatUnit: "day" },
      { id: ids[1], householdId: "h1", title: "Weekly", cadence: "weekly", repeatUnit: "week", days: "3" },
      { id: ids[2], householdId: "h1", title: "Monthly", cadence: "weekly", repeatUnit: "month", dueDate: "2026-01-07" },
      { id: ids[3], householdId: "h1", title: "Old one-off", cadence: "weekly", repeatUnit: "none" },
      { id: ids[4], householdId: "h1", title: "No current completion", repeatUnit: "day" },
    ]);
    const historical = Array.from({ length: 500 }, (_, index) => {
      const date = new Date(Date.UTC(2000, 0, 1 + index)).toISOString().slice(0, 10);
      return { choreId: ids[index % 2 === 0 ? 0 : 4], periodKey: date };
    });
    await db.insert(schema.choreCompletions).values([
      ...historical,
      { choreId: ids[0], periodKey: localDate },
      { choreId: ids[1], periodKey: "2026-W41" },
      { choreId: ids[2], periodKey: localDate },
      { choreId: ids[3], periodKey: "once", completedAt: new Date("2000-01-01T12:00:00Z") },
    ]);
    const reads = vi.spyOn(turso, "execute");
    try {
      const result = await call("guest", "chores", "GET", undefined, {}, `scope=all&localDate=${localDate}`);
      expect(result.status).toBe(200);
      const listed = result.json as Item[];
      for (const id of ids.slice(0, 4)) {
        expect(listed.find((item) => item.id === id), id).toMatchObject({ completed: true });
      }
      expect(listed.find((item) => item.id === ids[4])).toMatchObject({ completed: false });
      expect(listed.find((item) => item.id === ids[3])).toMatchObject({ completed: true, dueToday: false });

      const completionReads = reads.mock.calls.flatMap(([statement], index) => {
        const input = statement as InStatement;
        const query = typeof input === "string" ? input : input.sql;
        return query.toLowerCase().startsWith("select") && query.includes("chore_completions")
          ? [reads.mock.results[index].value]
          : [];
      });
      expect(completionReads).toHaveLength(1);
      const returned = await completionReads[0];
      // This inspects what the database returned, not just what the handler filtered afterward.
      expect(returned.rows.length).toBeLessThan(20);
      expect(returned.rows.every((row: Record<string, unknown>) =>
        [localDate, "2026-W41", "once"].includes(String(row.period_key)),
      )).toBe(true);

      const due = await call("guest", "chores", "GET", undefined, {}, `localDate=${localDate}`);
      expect((due.json as Item[]).some((item) => item.id === ids[3])).toBe(false);
      expect((due.json as Item[]).find((item) => item.id === ids[1])).toMatchObject({ completed: true, periodKey: "2026-W41" });
    } finally {
      reads.mockRestore();
      for (const id of ids) await db.delete(schema.chores).where(eq(schema.chores.id, id));
    }
  });
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

describe("timed chores in the dashboard", () => {
  it("sends the next few days of chores with a time, for reminders", async () => {
    const created = await call("parent", "chores", "POST", { title: "Take the bins out", repeatUnit: "day", dueTime: "07:30" });
    const dashboard = await call("guest", "dashboard", "GET");
    const mine = (dashboard.json.upcomingChores as { id: string; date: string; dueTime: string }[]).filter(
      (entry) => entry.id === created.json.id,
    );
    expect(mine).toHaveLength(3);
    expect(mine.every((entry) => entry.dueTime === "07:30")).toBe(true);
    expect(new Set(mine.map((entry) => entry.date)).size).toBe(3);
  });
});

describe("weekly completions use the household's calendar date", () => {
  it.each([
    ["Asia/Tokyo", "2026-10-05", "2026-W41"],
    ["Pacific/Kiritimati", "2027-01-04", "2027-W01"],
    ["Pacific/Auckland", "2026-12-28", "2026-W53"],
    ["America/Chicago", "2026-10-04", "2026-W40"],
  ])("%s on %s loads the correct completion", async (timezone, localDate, periodKey) => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const dates = await import("@/lib/dates");
    const id = `weekly-${timezone}-${localDate}`;
    const [household] = await db.select().from(schema.households).where(eq(schema.households.id, "h1"));
    await db.update(schema.households).set({ timezone }).where(eq(schema.households.id, "h1"));
    await db.insert(schema.chores).values({
      id, householdId: "h1", title: "Weekly test", cadence: "weekly", repeatUnit: "week",
      repeatInterval: 1, days: localDate === "2026-10-04" ? "0" : "1",
    });
    await db.insert(schema.choreCompletions).values({ choreId: id, periodKey });
    // Fix the household date without advancing the auth session's clock or its expiry.
    const date = vi.spyOn(dates, "localDateIn").mockReturnValue(localDate);
    try {
      const dashboard = await call("guest", "dashboard", "GET");
      expect(dashboard.status).toBe(200);
      expect(dashboard.json.localDate).toBe(localDate);
      expect(dashboard.json.chores.find((chore: Item) => chore.id === id)).toMatchObject({
        periodKey, completed: true, completedAt: expect.any(String),
      });
    } finally {
      date.mockRestore();
      await db.delete(schema.chores).where(eq(schema.chores.id, id));
      await db.update(schema.households).set({ timezone: household.timezone }).where(eq(schema.households.id, "h1"));
    }
  });
});
