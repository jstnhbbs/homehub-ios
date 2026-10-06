import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-routines-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

const password = "correct-horse-battery";
let cookie = "";

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
  return { status: response.status, json: JSON.parse(await response.text()) };
}

type Step = { id: string; label: string };

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values({ id: "h1", name: "T", inviteCode: "A", guestInviteCode: "B" });
  const created = await auth.api.signUpEmail({ body: { name: "parent", email: "parent@example.com", password } });
  const signedIn = await auth.api.signInEmail({ body: { email: "parent@example.com", password }, returnHeaders: true });
  cookie = signedIn.headers.getSetCookie().map((value) => value.split(";")[0]).join("; ");
  await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role: "parent" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

/** Today's weekday in the household, and the other six, as the server will see them. */
async function todayAndOthers() {
  const dashboard = await call("dashboard", "GET");
  const [year, month, day] = (dashboard.json.localDate as string).split("-").map(Number);
  const today = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  const others = [0, 1, 2, 3, 4, 5, 6].filter((weekday) => weekday !== today);
  return { today: String(today), others: others.join(",") };
}

const stepLabels = async () =>
  ((await call("dashboard", "GET")).json.routineSteps as { label: string; routineName: string }[]).map((step) => `${step.routineName}:${step.label}`);

describe("routine days", () => {
  it("runs every day unless told otherwise", async () => {
    const created = await call("routines", "POST", { name: "Daily", period: "morning", steps: ["Brush teeth"] });
    expect(created.status).toBe(201);
    expect(created.json.days).toBe("0,1,2,3,4,5,6");
    expect(await stepLabels()).toContain("Daily:Brush teeth");
  });

  it("leaves a routine off Today on the days it doesn't run", async () => {
    const { today, others } = await todayAndOthers();
    await call("routines", "POST", { name: "Not today", period: "morning", days: others, steps: ["Skip me"] });
    await call("routines", "POST", { name: "Only today", period: "morning", days: today, steps: ["Do me"] });
    const labels = await stepLabels();
    expect(labels).not.toContain("Not today:Skip me");
    expect(labels).toContain("Only today:Do me");
    // Still listed on the Routines page, which is where it is edited.
    const list = await call("routines", "GET");
    expect((list.json as { name: string }[]).map((routine) => routine.name)).toContain("Not today");
  });

  it("changes the days when edited, and leaves them alone when an older app doesn't say", async () => {
    const { others } = await todayAndOthers();
    const created = await call("routines", "POST", { name: "Edit me", period: "morning", days: others, steps: ["One"] });
    expect(created.json.days).toBe(others);
    const same = await call("routines/[id]", "PATCH", { name: "Edit me", period: "morning", steps: ["One"] }, { id: created.json.id });
    expect(same.json.days).toBe(others);
    const all = await call("routines/[id]", "PATCH", { name: "Edit me", period: "morning", days: "6,0,3", steps: ["One"] }, { id: created.json.id });
    expect(all.json.days).toBe("0,3,6");
  });

  it("refuses a routine that never runs", async () => {
    const created = await call("routines", "POST", { name: "Never", period: "morning", days: "9", steps: ["One"] });
    expect(created.status).toBe(400);
    const routine = await call("routines", "POST", { name: "Fine", period: "morning", steps: ["One"] });
    const edited = await call("routines/[id]", "PATCH", { name: "Fine", period: "morning", days: "", steps: ["One"] }, { id: routine.json.id });
    expect(edited.status).toBe(400);
  });
});

describe("reordering steps", () => {
  it("keeps each step's row, so what was checked off stays with it", async () => {
    const created = await call("routines", "POST", { name: "Order", period: "evening", steps: ["First", "Second", "Third"] });
    const before = created.json.steps as Step[];
    const idOf = (steps: Step[], label: string) => steps.find((step) => step.label === label)!.id;

    await call("routines/toggle-step", "POST", { stepId: idOf(before, "Third"), localDate: "2026-10-05", completed: true });
    const edited = await call("routines/[id]", "PATCH", { name: "Order", period: "evening", steps: ["Third", "First", "Second"] }, { id: created.json.id });
    const after = edited.json.steps as Step[];

    expect(after.map((step) => step.label)).toEqual(["Third", "First", "Second"]);
    for (const label of ["First", "Second", "Third"]) {
      expect(idOf(after, label)).toBe(idOf(before, label));
    }
  });
});
