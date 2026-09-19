import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-recipe-tags-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Role = "parent" | "guest";
type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Recipe = { id: string; title: string; tags: string[] };

const cookies: Partial<Record<Role, string>> = {};
const password = "correct-horse-battery";
let recipeId = "";

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
  return { status: response.status, text, json: JSON.parse(text) };
}

const base = { title: "Tacos", ingredients: ["1 lb chicken"], directions: ["Cook"] };

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

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("recipe tags", () => {
  it("cleans up tags when a recipe is created", async () => {
    const created = await call("parent", "recipes", "POST", {
      ...base,
      tags: ["dinner", "CHICKEN", " slow  cooker ", "Dinner", ""],
    });
    expect(created.status).toBe(201);
    expect(created.json.tags).toEqual(["Dinner", "Chicken", "Slow Cooker"]);
    recipeId = created.json.id;
  });

  it("starts with no tags when none are sent", async () => {
    const created = await call("parent", "recipes", "POST", { ...base, title: "Plain" });
    expect(created.json.tags).toEqual([]);
  });

  it("returns tags to everyone in the household", async () => {
    const list = await call("guest", "recipes", "GET");
    const tacos = (list.json as Recipe[]).find((recipe) => recipe.id === recipeId)!;
    expect(tacos.tags).toEqual(["Dinner", "Chicken", "Slow Cooker"]);
  });

  it("keeps tags when an older app edits a recipe without sending them", async () => {
    const edited = await call("parent", "recipes/[id]", "PATCH", { ...base, title: "Better tacos" }, { id: recipeId });
    expect(edited.status).toBe(200);
    expect(edited.json.title).toBe("Better tacos");
    expect(edited.json.tags).toEqual(["Dinner", "Chicken", "Slow Cooker"]);
  });

  it("replaces tags when new ones are sent, and clears them with an empty list", async () => {
    const replaced = await call("parent", "recipes/[id]", "PATCH", { ...base, tags: ["Lunch", "beef"] }, { id: recipeId });
    expect(replaced.json.tags).toEqual(["Lunch", "Beef"]);

    const cleared = await call("parent", "recipes/[id]", "PATCH", { ...base, tags: [] }, { id: recipeId });
    expect(cleared.json.tags).toEqual([]);
  });

  it("does not let guests tag or retag recipes", async () => {
    const created = await call("guest", "recipes", "POST", { ...base, tags: ["Dinner"] });
    expect(created.status).toBe(403);
    const edited = await call("guest", "recipes/[id]", "PATCH", { ...base, tags: ["Dinner"] }, { id: recipeId });
    expect(edited.status).toBe(403);
  });

  it("suggests tags for a recipe being edited", async () => {
    const suggested = await call("parent", "recipes/suggest-tags", "POST", {
      title: "Sheet pan chicken",
      ingredients: ["2 lb chicken thighs", "1 cup chicken broth"],
    });
    expect(suggested.status).toBe(200);
    expect(suggested.json.tags).toEqual(["Chicken"]);
  });

  it("includes tags as a readable list in the household export", async () => {
    await call("parent", "recipes/[id]", "PATCH", { ...base, tags: ["Dinner", "Fish"] }, { id: recipeId });
    const exported = await call("parent", "household/export", "GET");
    const recipe = exported.json.recipes.find((item: { id: string }) => item.id === recipeId);
    expect(recipe.tags).toEqual(["Dinner", "Fish"]);
  });
});
