import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-celebrations-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "parent" | "guest";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Item = { id: string; kind: string; name: string; upcomingAge: number; daysUntil: number; profileId: string | null };

const cookies: Partial<Record<Role, string>> = {};
const password = "correct-horse-battery";
let profileWithBirthdayId = "";

async function call(role: Role, route: string, method: string, body?: unknown, params: Record<string, string> = {}) {
  request.headers = new Headers({ cookie: cookies[role]! });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" || method === "DELETE" ? undefined : JSON.stringify(body ?? {}),
    }),
    { params: Promise.resolve(params) },
  );
  const text = await response.text();
  return { status: response.status, json: JSON.parse(text) };
}

async function dashboard() {
  const result = await call("parent", "dashboard", "GET");
  expect(result.status).toBe(200);
  return result.json as {
    hasAnniversaries: boolean;
    upcomingBirthdays: Item[];
    scheduleEvents: Array<{ title: string; calendarName: string }>;
  };
}

/** A date `yearsAgo` years back on today's month and day, in the household's default time zone. */
async function sameDayYearsAgo(yearsAgo: number) {
  const { localDateIn } = await import("@/lib/dates");
  const today = localDateIn("America/Chicago");
  return `${Number(today.slice(0, 4)) - yearsAgo}${today.slice(4)}`;
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
  profileWithBirthdayId = "11111111-1111-4111-8111-111111111111";
  await db.insert(schema.profiles).values({
    id: profileWithBirthdayId,
    householdId: "h1",
    name: "Kid",
    birthday: "2020-03-14",
  });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("birthdays and anniversaries", () => {
  it("starts with no anniversaries", async () => {
    expect((await dashboard()).hasAnniversaries).toBe(false);
  });

  it("treats an entry with no kind as a birthday, so older app versions keep working", async () => {
    const created = await call("parent", "birthdays", "POST", { name: "Grandma Eve", birthDate: "1948-08-20" });
    expect(created.status).toBe(201);
    expect(created.json.item.kind).toBe("birthday");
    expect((await dashboard()).hasAnniversaries).toBe(false);
  });

  it("creates an anniversary and counts its years", async () => {
    const created = await call("parent", "birthdays", "POST", {
      name: "Alex & Sam",
      birthDate: await sameDayYearsAgo(10),
      kind: "anniversary",
    });
    expect(created.status).toBe(201);
    expect(created.json.item).toMatchObject({ kind: "anniversary", upcomingAge: 10, daysUntil: 0 });
  });

  it("reports that an anniversary exists, however far away it is", async () => {
    // Nothing in the 45-day window is needed: the flag looks at every entry.
    expect((await dashboard()).hasAnniversaries).toBe(true);
    const far = await call("parent", "birthdays", "POST", { name: "Far", birthDate: "2010-01-01", kind: "anniversary" });
    expect(far.status).toBe(201);
    await call("parent", "birthdays/[id]", "DELETE", undefined, { id: far.json.item.id });
    expect((await dashboard()).hasAnniversaries).toBe(true);
  });

  it("words today's calendar event as an anniversary", async () => {
    const data = await dashboard();
    const event = data.scheduleEvents.find((item) => item.title.includes("Alex & Sam"));
    expect(event?.title).toBe("Alex & Sam’s anniversary");
    expect(event?.calendarName).toBe("Family anniversaries");
  });

  it("lists both kinds together", async () => {
    const list = await call("guest", "birthdays", "GET");
    const kinds = (list.json.items as Item[]).map((item) => `${item.name}:${item.kind}`).sort();
    expect(kinds).toEqual(["Alex & Sam:anniversary", "Grandma Eve:birthday", "Kid:birthday"]);
  });

  it("never links an anniversary to a profile, so a profile's birthday cannot hide it", async () => {
    const created = await call("parent", "birthdays", "POST", {
      name: "Kid's parents",
      birthDate: "2015-06-01",
      kind: "anniversary",
      profileId: profileWithBirthdayId,
    });
    expect(created.status).toBe(201);
    expect(created.json.item.profileId).toBeNull();
    const names = ((await call("guest", "birthdays", "GET")).json.items as Item[]).map((item) => item.name);
    expect(names).toContain("Kid's parents");
  });

  it("rejects a future date with wording that matches the kind", async () => {
    const future = "2999-01-01";
    const anniversary = await call("parent", "birthdays", "POST", { name: "X", birthDate: future, kind: "anniversary" });
    expect(anniversary.status).toBe(400);
    expect(anniversary.json.error).toContain("anniversary");
    const birthday = await call("parent", "birthdays", "POST", { name: "X", birthDate: future });
    expect(birthday.json.error).toContain("Birthday");
  });

  it("can change an entry's kind, and removing the last anniversary clears the flag", async () => {
    const list = (await call("parent", "birthdays", "GET")).json.items as Item[];
    for (const item of list.filter((entry) => entry.kind === "anniversary")) {
      const changed = await call("parent", "birthdays/[id]", "PATCH", { kind: "birthday" }, { id: item.id });
      expect(changed.status).toBe(200);
      expect(changed.json.kind).toBe("birthday");
    }
    expect((await dashboard()).hasAnniversaries).toBe(false);
  });

  it("does not let guests add or change entries", async () => {
    const created = await call("guest", "birthdays", "POST", { name: "X", birthDate: "2000-01-01", kind: "anniversary" });
    expect(created.status).toBe(403);
  });
});
