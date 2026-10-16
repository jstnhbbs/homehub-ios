import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

// The route reads the session from next/headers, so the test supplies the owner's cookie.
const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "tugboat-naps-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

const password = "correct-horse-battery";
let cookie = "";
let childProfile = "";

type Nap = { id: string; startedAt: string; endedAt: string | null };

async function post(body: unknown) {
  request.headers = new Headers({ cookie });
  const { POST } = await import("@/app/api/mobile/v1/naps/route");
  const response = await POST(
    new Request("http://localhost:3000/api/mobile/v1/naps", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    }),
  );
  const json = (await response.json()) as { error?: string; nap?: Nap };
  return { status: response.status, error: json.error ?? "", nap: json.nap };
}

/** A time some minutes ago, in whole seconds (that is the precision the database keeps). */
function minutesAgo(minutes: number) {
  return new Date(Math.floor((Date.now() - minutes * 60_000) / 1000) * 1000).toISOString();
}

/** Moves a running sleep's start back, so there is time between its start and an end time to choose. */
async function startedMinutesAgo(napId: string, minutes: number) {
  const { db } = await import("@/db/client");
  const { napLogs } = await import("@/db/schema");
  const { eq } = await import("drizzle-orm");
  await db.update(napLogs).set({ startedAt: new Date(Date.now() - minutes * 60_000) }).where(eq(napLogs.id, napId));
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  await db.insert(schema.households).values({ id: "h1", name: "Test Family", inviteCode: "INV1", guestInviteCode: "GUEST1" });
  const email = "owner@example.com";
  const created = await auth.api.signUpEmail({ body: { name: "Owner", email, password } });
  const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
  cookie = signedIn.headers.getSetCookie().map((value) => value.split(";")[0]).join("; ");
  await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role: "owner" });
  childProfile = "11111111-1111-4111-8111-111111111111";
  await db.insert(schema.profiles).values({ id: childProfile, householdId: "h1", profileType: "child", name: "Maya" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("ending a sleep with the time it was tapped", () => {
  it("records the tap time when a widget could only sync later", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    expect(started.status).toBe(200);
    await startedMinutesAgo(started.nap!.id, 60);
    const tapped = minutesAgo(20);
    const ended = await post({ action: "end", napId: started.nap!.id, endedAt: tapped });
    expect(ended.status).toBe(200);
    expect(ended.nap!.endedAt).toBe(tapped);
  });

  it("records now when no time is sent, as older apps do", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    await startedMinutesAgo(started.nap!.id, 10);
    const before = Date.now();
    const ended = await post({ action: "end", napId: started.nap!.id });
    expect(ended.status).toBe(200);
    expect(new Date(ended.nap!.endedAt!).getTime()).toBeGreaterThanOrEqual(before - 1000);
  });

  it("refuses an end time in the future, and the sleep stays running", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    const refused = await post({ action: "end", napId: started.nap!.id, endedAt: new Date(Date.now() + 3_600_000).toISOString() });
    expect(refused.status).toBe(400);
    expect(refused.error).toContain("future");
    const retried = await post({ action: "end", napId: started.nap!.id });
    expect(retried.status).toBe(200);
  });

  it("refuses an end time before the sleep began", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    const refused = await post({ action: "end", napId: started.nap!.id, endedAt: new Date(Date.now() - 3_600_000).toISOString() });
    expect(refused.status).toBe(400);
    await post({ action: "end", napId: started.nap!.id });
  });

  it("refuses an end time more than a day old", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    await startedMinutesAgo(started.nap!.id, 3 * 24 * 60);
    const refused = await post({ action: "end", napId: started.nap!.id, endedAt: new Date(Date.now() - 2 * 24 * 3_600_000).toISOString() });
    expect(refused.status).toBe(400);
    expect(refused.error).toContain("too long ago");
    await post({ action: "end", napId: started.nap!.id });
  });

  it("refuses a malformed end time", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    const refused = await post({ action: "end", napId: started.nap!.id, endedAt: "yesterday" });
    expect(refused.status).toBe(400);
    await post({ action: "end", napId: started.nap!.id });
  });

  it("accepts the tap time when ending by profile too", async () => {
    const started = await post({ action: "start", profileId: childProfile });
    await startedMinutesAgo(started.nap!.id, 30);
    const tapped = minutesAgo(5);
    const ended = await post({ action: "end", profileId: childProfile, endedAt: tapped });
    expect(ended.status).toBe(200);
    expect(ended.nap!.endedAt).toBe(tapped);
  });
});
