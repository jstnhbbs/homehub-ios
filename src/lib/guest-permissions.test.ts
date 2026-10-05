import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

// The mobile routes read the session from next/headers, so each call swaps in that user's cookie.
const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-guest-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "owner" | "parent" | "guest" | "anonymous";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

const cookies: Partial<Record<Role, string>> = {};
const ids = { guestProfile: "", ownerProfile: "", note: "" };
const password = "correct-horse-battery";

/** Calls a route handler as the given role and returns its status and parsed body. */
async function call(
  role: Role,
  route: string,
  method: string,
  options: { body?: unknown; query?: string; params?: Record<string, string> } = {},
) {
  request.headers = new Headers(cookies[role] ? { cookie: cookies[role]! } : {});
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const handler = routeModule[method];
  expect(handler, `${method} ${route} should exist`).toBeTypeOf("function");
  const response = await handler(
    new Request(`http://localhost:3000/api/mobile/v1/${route}${options.query ?? ""}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" || method === "DELETE" ? undefined : JSON.stringify(options.body ?? {}),
    }),
    { params: Promise.resolve(options.params ?? {}) },
  );
  const text = await response.text();
  let json: { error?: string } = {};
  try {
    json = JSON.parse(text);
  } catch {
    // Not every response is JSON (the export is a file).
  }
  return { status: response.status, error: json.error ?? "", json };
}

function isDenied(result: { status: number; error: string }) {
  return result.status === 403 || (result.status === 400 && result.error.includes("permission"));
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({
    id: "h1",
    name: "Test Family",
    inviteCode: "INV1",
    guestInviteCode: "GUEST1",
  });

  for (const role of ["owner", "parent", "guest"] as const) {
    const email = `${role}@example.com`;
    const created = await auth.api.signUpEmail({ body: { name: role, email, password } });
    const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
    cookies[role] = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    await db
      .insert(schema.householdMembers)
      .values({ householdId: "h1", userId: created.user.id, role });
  }

  // Any signed-in call creates the members' profiles; look them up for the profile tests.
  await call("owner", "dashboard", "GET");
  const profiles = await db.select().from(schema.profiles);
  const users = await db.select().from(schema.users);
  const userId = (email: string) => users.find((user) => user.email === email)!.id;
  ids.guestProfile = profiles.find((p) => p.userId === userId("guest@example.com"))!.id;
  ids.ownerProfile = profiles.find((p) => p.userId === userId("owner@example.com"))!.id;

  const note = await call("owner", "notes", "POST", { body: { title: "Owner note" } });
  ids.note = (note.json as unknown as { id: string }).id;
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

// Routes that change household setup or shared data. Guests must be refused; parents must reach
// the handler (an empty body may then fail validation, which is fine: the guard is what we test).
const parentOnly: Array<[method: string, route: string, params?: Record<string, string>]> = [
  ["POST", "meals"],
  ["POST", "meals/clear-week"],
  ["POST", "meals/copy-previous-week"],
  ["POST", "chores"],
  ["PATCH", "chores/[id]", { id: "x" }],
  ["DELETE", "chores/[id]", { id: "x" }],
  ["POST", "routines"],
  ["PATCH", "routines/[id]", { id: "x" }],
  ["DELETE", "routines/[id]", { id: "x" }],
  ["POST", "recipes"],
  ["PATCH", "recipes/[id]", { id: "x" }],
  ["DELETE", "recipes/[id]", { id: "x" }],
  ["POST", "recipes/import"],
  ["POST", "recipes/import/crouton"],
  ["POST", "recipes/[id]/image", { id: "x" }],
  ["POST", "recipes/suggest-tags"],
  ["POST", "profiles"],
  ["POST", "birthdays"],
  ["PATCH", "birthdays/[id]", { id: "x" }],
  ["DELETE", "birthdays/[id]", { id: "x" }],
  ["POST", "groceries"],
  ["PATCH", "groceries/[id]", { id: "x" }],
  ["DELETE", "groceries/[id]", { id: "x" }],
  ["POST", "groceries/clear-checked"],
  ["PATCH", "notes/[id]", { id: "x" }],
  ["DELETE", "notes/[id]", { id: "x" }],
  ["POST", "snacks/options"],
  ["POST", "household/photo"],
  ["DELETE", "household/photo"],
  ["PATCH", "household/members/[userId]", { userId: "nobody" }],
  ["DELETE", "household/members/[userId]", { userId: "nobody" }],
  ["PATCH", "calendar/settings"],
  ["GET", "household/export"],
];

describe("guests are refused on every setup and management route", () => {
  it.each(parentOnly)("%s %s", async (method, route, params) => {
    const guest = await call("guest", route, method, { params });
    expect(isDenied(guest), `guest got ${guest.status}: ${guest.error}`).toBe(true);
  });
});

describe("parents and owners are not blocked by the guard", () => {
  it.each(parentOnly)("%s %s", async (method, route, params) => {
    for (const role of ["parent", "owner"] as const) {
      const result = await call(role, route, method, { params });
      expect(isDenied(result), `${role} got ${result.status}: ${result.error}`).toBe(false);
      expect(result.status).not.toBe(401);
    }
  });
});

describe("signed-out requests are rejected", () => {
  it.each([
    ["GET", "dashboard"],
    ["GET", "groceries"],
    ["POST", "notes"],
    ["POST", "chores/toggle"],
    ["GET", "household/export"],
  ])("%s %s", async (method, route) => {
    expect((await call("anonymous", route, method)).status).toBe(401);
  });
});

describe("what guests can do", () => {
  it("can read the household's data", async () => {
    for (const route of ["dashboard", "groceries", "notes", "routines", "recipes", "birthdays", "household/members"]) {
      const result = await call("guest", route, "GET");
      expect(result.status, route).toBe(200);
    }
    const meals = await call("guest", "meals", "GET", { query: "?weekStart=2026-09-14" });
    expect(meals.status).toBe(200);
  });

  it("can add a note, but not edit or delete one", async () => {
    const added = await call("guest", "notes", "POST", { body: { title: "Kids were great" } });
    expect(added.status).toBe(201);
    const noteId = (added.json as unknown as { id: string }).id;

    expect(isDenied(await call("guest", "notes/[id]", "PATCH", { params: { id: noteId }, body: { title: "x" } }))).toBe(true);
    expect(isDenied(await call("guest", "notes/[id]", "DELETE", { params: { id: noteId } }))).toBe(true);
    expect(isDenied(await call("guest", "notes/[id]", "DELETE", { params: { id: ids.note } }))).toBe(true);
  });

  it("can log activity: naps and check-offs pass the permission guard", async () => {
    const logging: Array<[string, string, Record<string, string>?]> = [
      ["POST", "naps"],
      ["PATCH", "naps/[id]", { id: "x" }],
      ["DELETE", "naps/[id]", { id: "x" }],
      ["POST", "routines/toggle-step"],
      ["POST", "chores/toggle"],
      ["POST", "snacks/toggle"],
      ["POST", "snacks/reset"],
    ];
    for (const [method, route, params] of logging) {
      const result = await call("guest", route, method, { params });
      expect(isDenied(result), `${method} ${route} -> ${result.status}: ${result.error}`).toBe(false);
      expect(result.status).not.toBe(401);
    }
  });

  it("can edit their own profile but not anyone else's", async () => {
    const body = { name: "Guest Person", profileType: "adult", color: "#4f7c6d" };
    const own = await call("guest", "profiles/[id]", "PATCH", { params: { id: ids.guestProfile }, body });
    expect(own.status).toBe(200);

    const other = await call("guest", "profiles/[id]", "PATCH", { params: { id: ids.ownerProfile }, body });
    expect(other.status).toBe(403);
  });

  it("cannot change another person's profile photo", async () => {
    const result = await call("guest", "profiles/[id]/photo", "DELETE", { params: { id: ids.ownerProfile } });
    expect(isDenied(result)).toBe(true);
  });

  it("can change their own hub layout preferences", async () => {
    expect((await call("guest", "hub-modules", "GET")).status).toBe(200);
    expect((await call("guest", "hub-modules", "PATCH", { body: { calendar: false } })).status).toBe(200);
  });
});

describe("invite codes stay with people who can manage the household", () => {
  const sources: Array<[route: string, pick: (json: Record<string, unknown>) => Record<string, unknown>]> = [
    ["household", (json) => json],
    ["dashboard", (json) => json.household as Record<string, unknown>],
  ];

  it.each(sources)("%s hides both codes from a guest", async (route, pick) => {
    const guest = await call("guest", route, "GET");
    expect(guest.status).toBe(200);
    const household = pick(guest.json as Record<string, unknown>);
    // Empty strings, not missing keys: older app versions decode both as required.
    expect(household.inviteCode).toBe("");
    expect(household.guestInviteCode).toBe("");
    expect(JSON.stringify(guest.json)).not.toContain("INV1");
    expect(JSON.stringify(guest.json)).not.toContain("GUEST1");
  });

  it.each(sources)("%s still gives parents and owners both codes", async (route, pick) => {
    for (const role of ["parent", "owner"] as const) {
      const result = await call(role, route, "GET");
      const household = pick(result.json as Record<string, unknown>);
      expect(household.inviteCode, `${role} ${route}`).toBe("INV1");
      expect(household.guestInviteCode, `${role} ${route}`).toBe("GUEST1");
    }
  });
});
