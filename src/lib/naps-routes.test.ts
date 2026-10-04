import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-naps-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Nap = { id: string; profileId: string; kind: string; startedAt: string; endedAt: string | null };

const password = "correct-horse-battery";
let cookie = "";
const kid = "11111111-1111-4111-8111-111111111111";
const otherKid = "22222222-2222-4222-8222-222222222222";

async function call(route: string, method: string, body?: unknown, params: Record<string, string> = {}) {
  request.headers = new Headers({ cookie });
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
  return { status: response.status, json: JSON.parse(text) as Record<string, unknown> };
}

const post = (body: unknown) => call("naps", "POST", body);
const iso = (minutesAgo: number) => new Date(Date.now() - minutesAgo * 60_000).toISOString();

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B" });
  await db.insert(schema.profiles).values([
    { id: kid, householdId: "h1", name: "Ada", profileType: "child", color: "#d87861" },
    { id: otherKid, householdId: "h1", name: "Ben", profileType: "child", color: "#6689a3" },
  ]);
  const created = await auth.api.signUpEmail({ body: { name: "Parent", email: "p@example.com", password } });
  const signedIn = await auth.api.signInEmail({ body: { email: "p@example.com", password }, returnHeaders: true });
  cookie = signedIn.headers
    .getSetCookie()
    .map((value) => value.split(";")[0])
    .join("; ");
  await db
    .insert(schema.householdMembers)
    .values({ householdId: "h1", userId: created.user.id, role: "owner" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("sleep writes hand back the entry they changed", () => {
  it("returns the new nap when one is started, and keeps ok and id for older apps", async () => {
    const started = await post({ action: "start", profileId: kid });
    expect(started.status).toBe(200);
    expect(started.json.ok).toBe(true);
    const nap = started.json.nap as Nap;
    expect(started.json.id).toBe(nap.id);
    expect(nap).toMatchObject({ profileId: kid, kind: "nap", endedAt: null });
  });

  it("refuses a second running sleep for the same child, even when both checks run together", async () => {
    const second = await post({ action: "startNight", profileId: kid });
    expect(second.status).toBe(400);
    expect(second.json.error).toContain("already has sleep in progress");
  });

  it("returns the finished nap when it is ended by child or by id", async () => {
    const ended = await post({ action: "end", profileId: kid });
    expect(ended.status).toBe(200);
    const nap = ended.json.nap as Nap;
    expect(nap.endedAt).not.toBeNull();
    expect(ended.json.id).toBe(nap.id);

    const started = await post({ action: "start", profileId: otherKid });
    const id = (started.json.nap as Nap).id;
    const endedById = await post({ action: "end", napId: id });
    expect((endedById.json.nap as Nap).endedAt).not.toBeNull();
  });

  it("returns manual entries, with the wake time when one is given", async () => {
    const nap = await post({ action: "create", profileId: kid, startedAt: iso(240), endedAt: iso(180) });
    expect((nap.json.nap as Nap).endedAt).not.toBeNull();

    const open = await post({ action: "createNight", profileId: otherKid, fellAsleepAt: iso(30) });
    expect(open.status).toBe(200);
    expect(open.json.nap).toMatchObject({ kind: "night", endedAt: null });
  });

  it("rejects a wake time before the sleep time and a child from elsewhere", async () => {
    const backwards = await post({ action: "create", profileId: kid, startedAt: iso(60), endedAt: iso(120) });
    expect(backwards.status).toBe(400);
    const stranger = await post({ action: "start", profileId: "99999999-9999-4999-8999-999999999999" });
    expect(stranger.status).toBe(400);
  });

  it("returns the edited entry on PATCH and nothing on DELETE", async () => {
    const created = await post({ action: "create", profileId: kid, startedAt: iso(500), endedAt: iso(440) });
    const id = (created.json.nap as Nap).id;
    const newStart = new Date(Math.floor((Date.now() - 520 * 60_000) / 1000) * 1000).toISOString();
    const patched = await call("naps/[id]", "PATCH", { startedAt: newStart, endedAt: iso(440) }, { id });
    expect(patched.status).toBe(200);
    // Stored to the second, so compare at that precision.
    expect((patched.json.nap as Nap).startedAt).toBe(newStart);

    const deleted = await call("naps/[id]", "DELETE", undefined, { id });
    expect(deleted.status).toBe(200);
    const page = await call("naps", "GET");
    const logs = page.json.weekLogs as Nap[];
    expect(logs.some((log) => log.id === id)).toBe(false);
  });
});

describe("the sleep page", () => {
  it("lists every running sleep and every entry from the week in one payload", async () => {
    const page = await call("naps", "GET");
    expect(page.status).toBe(200);
    const naps = page.json.naps as Nap[];
    const week = page.json.weekLogs as Nap[];
    // Today's entries are derived from the week query, so each one must also appear there.
    for (const nap of naps) expect(week.some((log) => log.id === nap.id)).toBe(true);
    // The night left running for Ben is reported as active.
    expect(week.some((log) => log.profileId === otherKid && log.kind === "night" && log.endedAt === null)).toBe(true);
  });
});
