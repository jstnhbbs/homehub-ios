import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-snacks-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "parent" | "guest";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

const password = "correct-horse-battery";
const cookies: Partial<Record<Role, string>> = {};
const kids = { a: "11111111-1111-4111-8111-111111111111", b: "22222222-2222-4222-8222-222222222222" };
const adult = "33333333-3333-4333-8333-333333333333";
let today = "";

async function call(role: Role, route: string, method: string, body?: unknown) {
  request.headers = new Headers({ cookie: cookies[role]! });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" ? undefined : JSON.stringify(body ?? {}),
    }),
    { params: Promise.resolve({}) },
  );
  const text = await response.text();
  return { status: response.status, json: JSON.parse(text) };
}

async function dashboard() {
  const result = await call("parent", "dashboard", "GET");
  expect(result.status).toBe(200);
  return result.json as {
    snacksPerChild: boolean;
    snackEaten: string[];
    snackCompletions: Array<{ snackLabel: string; profileId: string | null }>;
  };
}

const eat = (role: Role, snackLabel: string, profileId?: string) =>
  call(role, "snacks/toggle", "POST", { localDate: today, snackLabel, profileId });

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { localDateIn } = await import("@/lib/dates");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  today = localDateIn("America/Chicago");
  await db.insert(schema.households).values({
    id: "h1",
    name: "T",
    inviteCode: "A",
    guestInviteCode: "B",
    snackOptions: "Apples\nYogurt",
  });
  await db.insert(schema.profiles).values([
    { id: kids.a, householdId: "h1", name: "Ava", profileType: "child", color: "#d87861" },
    { id: kids.b, householdId: "h1", name: "Ben", profileType: "child", color: "#6689a3" },
    { id: adult, householdId: "h1", name: "Parent", profileType: "adult", color: "#4f7c6d" },
  ]);
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

describe("snacks for the whole household (the default)", () => {
  it("is off until a parent turns it on", async () => {
    expect((await dashboard()).snacksPerChild).toBe(false);
  });

  it("checks a snack off for everyone, as every app version has", async () => {
    expect((await eat("guest", "Apples")).status).toBe(200);
    const data = await dashboard();
    expect(data.snackEaten).toEqual(["Apples"]);
    expect(data.snackCompletions).toEqual([{ snackLabel: "Apples", profileId: null }]);
  });

  it("ignores a child sent along by mistake", async () => {
    await eat("guest", "Apples", kids.a);
    expect((await dashboard()).snackEaten).toEqual([]);
  });
});

describe("snacks per child", () => {
  it("only a parent can turn it on", async () => {
    expect((await call("guest", "snacks/options", "POST", { snacksPerChild: true })).status).toBe(403);
    const turnedOn = await call("parent", "snacks/options", "POST", { snacksPerChild: true });
    expect(turnedOn.status).toBe(200);
    expect(turnedOn.json.snacksPerChild).toBe(true);
    expect(turnedOn.json.snackOptions).toBe("Apples\nYogurt");
  });

  it("saving the snack list does not turn it back off", async () => {
    const saved = await call("parent", "snacks/options", "POST", { snackOptions: "Apples\nYogurt\nPretzels" });
    expect(saved.json.snacksPerChild).toBe(true);
    await call("parent", "snacks/options", "POST", { snackOptions: "Apples\nYogurt" });
  });

  it("rejects an update that changes nothing", async () => {
    expect((await call("parent", "snacks/options", "POST", {})).status).toBe(400);
  });

  it("needs to know which child", async () => {
    expect((await eat("guest", "Apples")).status).toBe(400);
  });

  it("rejects an adult or a stranger as the child", async () => {
    expect((await eat("guest", "Apples", adult)).status).toBe(400);
    expect((await eat("guest", "Apples", "44444444-4444-4444-8444-444444444444")).status).toBe(400);
  });

  it("records one child without the other", async () => {
    expect((await eat("guest", "Yogurt", kids.a)).status).toBe(200);
    const data = await dashboard();
    expect(data.snackCompletions).toEqual([{ snackLabel: "Yogurt", profileId: kids.a }]);
    expect(data.snackEaten).toEqual([]);
  });

  it("shows a snack as eaten once every child has had it", async () => {
    await eat("guest", "Yogurt", kids.b);
    expect((await dashboard()).snackEaten).toEqual(["Yogurt"]);
  });

  it("unchecks only that child", async () => {
    await eat("guest", "Yogurt", kids.a);
    const data = await dashboard();
    expect(data.snackEaten).toEqual([]);
    expect(data.snackCompletions).toEqual([{ snackLabel: "Yogurt", profileId: kids.b }]);
  });

  it("keeps the household-wide rows when switched back", async () => {
    await call("parent", "snacks/options", "POST", { snacksPerChild: false });
    expect((await dashboard()).snackEaten).toEqual([]);
    await eat("guest", "Apples");
    expect((await dashboard()).snackEaten).toEqual(["Apples"]);
  });

  it("falls back to the household-wide checklist when there are no children", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    await call("parent", "snacks/reset", "POST", { localDate: today });
    await db.delete(schema.profiles).where(eq(schema.profiles.profileType, "child"));
    expect((await dashboard()).snacksPerChild).toBe(false);
    expect((await eat("guest", "Yogurt")).status).toBe(200);
    expect((await dashboard()).snackEaten).toEqual(["Yogurt"]);
    await eat("guest", "Yogurt");
    await db.insert(schema.profiles).values([
      { id: kids.a, householdId: "h1", name: "Ava", profileType: "child", color: "#d87861" },
      { id: kids.b, householdId: "h1", name: "Ben", profileType: "child", color: "#6689a3" },
    ]);
  });

  it("reset clears every child's checks for the day", async () => {
    await call("parent", "snacks/options", "POST", { snacksPerChild: true });
    await eat("guest", "Apples", kids.a);
    await call("parent", "snacks/reset", "POST", { localDate: today });
    expect((await dashboard()).snackCompletions).toEqual([]);
  });
});
