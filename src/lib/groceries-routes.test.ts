import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-groceries-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

async function call(route: string, method: string, body?: unknown, params: Record<string, string> = {}) {
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "GET" || method === "DELETE" ? undefined : JSON.stringify(body ?? {}),
    }),
    { params: Promise.resolve(params) },
  );
  return { status: response.status, json: (await response.json()) as Record<string, unknown> };
}

async function titles() {
  const { db } = await import("@/db/client");
  const { groceryItems } = await import("@/db/schema");
  return (await db.select().from(groceryItems)).map((item) => item.title).sort();
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  await db.insert(schema.households).values({ id: "h", name: "H", inviteCode: "INV", guestInviteCode: "GST" });
  const created = await auth.api.signUpEmail({ body: { name: "Owner", email: "owner@example.com", password: "correct-horse-battery" } });
  const signedIn = await auth.api.signInEmail({ body: { email: "owner@example.com", password: "correct-horse-battery" }, returnHeaders: true });
  request.headers = new Headers({ cookie: signedIn.headers.getSetCookie().map((value) => value.split(";")[0]).join("; ") });
  await db.insert(schema.householdMembers).values({ householdId: "h", userId: created.user.id, role: "owner" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("grocery deletes", () => {
  it("deleting one item removes it, and nothing else", async () => {
    const milk = (await call("groceries", "POST", { title: "Milk" })).json as { id: string };
    await call("groceries", "POST", { title: "Eggs" });
    expect((await call("groceries/[id]", "DELETE", undefined, { id: milk.id })).status).toBe(200);
    expect(await titles()).toEqual(["Eggs"]);
  });

  it("deleting an item that is not there is refused", async () => {
    const result = await call("groceries/[id]", "DELETE", undefined, { id: "5b0d34b7-8ccb-4f83-8582-4e6cc14f5b62" });
    expect(result.status).toBe(400);
  });

  it("clearing checked items removes only the checked ones and says how many", async () => {
    const bread = (await call("groceries", "POST", { title: "Bread" })).json as { id: string };
    const jam = (await call("groceries", "POST", { title: "Jam" })).json as { id: string };
    await call("groceries/[id]", "PATCH", { checked: true }, { id: bread.id });
    await call("groceries/[id]", "PATCH", { checked: true }, { id: jam.id });
    const result = await call("groceries/clear-checked", "POST");
    expect(result.status).toBe(200);
    expect(result.json.cleared).toBe(2);
    expect(await titles()).toEqual(["Eggs"]);
  });
});
