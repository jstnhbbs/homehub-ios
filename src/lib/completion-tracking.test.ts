import { randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-completions-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "owner" | "parent" | "guest";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

const password = "correct-horse-battery";
const cookies: Partial<Record<Role, string>> = {};
const ids = { stepA: randomUUID(), stepB: randomUUID(), chore: randomUUID(), today: "" };
let authModule: typeof import("@/lib/auth");

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
  return { status: response.status, text, json: JSON.parse(text) };
}

async function dashboard() {
  const result = await call("owner", "dashboard", "GET");
  expect(result.status).toBe(200);
  return result.json as {
    routineSteps: Array<{ id: string; completed: boolean; completedAt: string | null; completedByName: string | null }>;
    chores: Array<{ id: string; completed: boolean; completedAt: string | null; completedByName: string | null }>;
  };
}

const stepState = async (id: string) => (await dashboard()).routineSteps.find((step) => step.id === id)!;

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  authModule = await import("@/lib/auth");
  const { localDateIn } = await import("@/lib/dates");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  ids.today = localDateIn("America/Chicago");
  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B" });
  for (const role of ["owner", "parent", "guest"] as const) {
    const email = `${role}@example.com`;
    const created = await authModule.auth.api.signUpEmail({ body: { name: role, email, password } });
    const signedIn = await authModule.auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
    cookies[role] = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role });
  }

  await db.insert(schema.routines).values({ id: "r1", householdId: "h1", name: "Morning", period: "morning" });
  await db.insert(schema.routineSteps).values([
    { id: ids.stepA, routineId: "r1", label: "Brush teeth" },
    { id: ids.stepB, routineId: "r1", label: "Get dressed" },
  ]);
  await db.insert(schema.chores).values({ id: ids.chore, householdId: "h1", title: "Feed the dog" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("who completed a routine step", () => {
  it("shows nobody until it is checked off", async () => {
    expect(await stepState(ids.stepA)).toMatchObject({ completed: false, completedAt: null, completedByName: null });
  });

  it("records the guest who checked it off, and when", async () => {
    const toggled = await call("guest", "routines/toggle-step", "POST", { stepId: ids.stepA, localDate: ids.today });
    expect(toggled.status).toBe(200);

    const step = await stepState(ids.stepA);
    expect(step.completed).toBe(true);
    expect(step.completedByName).toBe("guest");
    expect(Number.isNaN(Date.parse(step.completedAt!))).toBe(false);
  });

  it("records a different person for a different step", async () => {
    await call("parent", "routines/toggle-step", "POST", { stepId: ids.stepB, localDate: ids.today });
    expect((await stepState(ids.stepB)).completedByName).toBe("parent");
    expect((await stepState(ids.stepA)).completedByName).toBe("guest");
  });

  it("forgets the person when a step is unchecked", async () => {
    await call("owner", "routines/toggle-step", "POST", { stepId: ids.stepB, localDate: ids.today });
    expect(await stepState(ids.stepB)).toMatchObject({ completed: false, completedByName: null });
  });
});

describe("who completed a chore", () => {
  it("appears on both the dashboard and the chores list", async () => {
    const toggled = await call("owner", "chores/toggle", "POST", { choreId: ids.chore, periodKey: ids.today });
    expect(toggled.status).toBe(200);

    const onDashboard = (await dashboard()).chores.find((chore) => chore.id === ids.chore)!;
    expect(onDashboard).toMatchObject({ completed: true, completedByName: "owner" });

    const list = await call("guest", "chores", "GET");
    const listed = (list.json as Array<{ id: string; completedByName: string | null; completedAt: string | null }>).find(
      (chore) => chore.id === ids.chore,
    )!;
    expect(listed.completedByName).toBe("owner");
    expect(listed.completedAt).not.toBeNull();
  });
});

describe("privacy", () => {
  it("keeps who completed things out of the household export", async () => {
    const exported = await call("owner", "household/export", "GET");
    expect(exported.status).toBe(200);
    expect(exported.text).not.toContain("completedBy");
    expect(exported.json.routineCompletions.length).toBeGreaterThan(0);
  });

  it("keeps the completion but forgets who did it after they delete their account", async () => {
    await authModule.auth.api.deleteUser({
      body: { password },
      headers: new Headers({ cookie: cookies.guest! }),
    });

    const step = await stepState(ids.stepA);
    expect(step.completed).toBe(true);
    expect(step.completedByName).toBeNull();
  });
});
