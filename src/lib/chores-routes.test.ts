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
type Item = { id: string; title: string; dueDate: string | null; overdue: boolean };

const password = "correct-horse-battery";
const cookies: Partial<Record<Role, string>> = {};
let today = "";

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
  const { localDateIn } = await import("@/lib/dates");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  today = localDateIn("America/Chicago");
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

  it("saves a due date, independent of cadence", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Book report",
      cadence: "daily",
      dueDate: "2099-01-05",
    });
    expect(created.status).toBe(201);
    expect(created.json.dueDate).toBe("2099-01-05");

    const list = await call("guest", "chores", "GET");
    const listed = (list.json as Item[]).find((item) => item.id === created.json.id)!;
    expect(listed.dueDate).toBe("2099-01-05");
    expect(listed.overdue).toBe(false);
  });

  it("flags a past due date as overdue until it's completed", async () => {
    const created = await call("parent", "chores", "POST", {
      title: "Permission slip",
      cadence: "daily",
      dueDate: "2000-01-01",
    });

    const list = await call("guest", "chores", "GET");
    const listed = (list.json as Item[]).find((item) => item.id === created.json.id)!;
    expect(listed.overdue).toBe(true);

    await call("guest", "chores/toggle", "POST", { choreId: created.json.id, periodKey: today });
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
