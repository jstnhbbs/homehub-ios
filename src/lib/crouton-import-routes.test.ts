import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

// The photo store is Vercel Blob in production; here it is a recording stand-in.
const blob = vi.hoisted(() => ({
  put: vi.fn(),
  del: vi.fn(),
}));
vi.mock("@vercel/blob", () => ({
  put: blob.put,
  del: blob.del,
  head: vi.fn(),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-crouton-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;
type Who = "parent" | "guest" | "nobody";
type ImportResult = { index: number; title: string; status: string; id?: string; error?: string; hasPhoto?: boolean };
type Json = {
  error?: string;
  imageUrl?: string;
  created: number;
  duplicates: number;
  failed: number;
  results: ImportResult[];
};

const password = "correct-horse-battery";
const cookies: Record<string, string> = {};

async function call(
  who: Who,
  route: string,
  method: string,
  body?: BodyInit | object,
  params: Record<string, string> = {},
) {
  request.headers = new Headers(cookies[who] ? { cookie: cookies[who] } : {});
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const isForm = body instanceof FormData;
  const response = await routeModule[method](
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method,
      headers: isForm || body === undefined ? undefined : { "content-type": "application/json" },
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    }),
    { params: Promise.resolve(params) },
  );
  return { status: response.status, json: (await response.json()) as Json };
}

/** A recipe as it would arrive from the app: the export's text fields, no photos. */
function crouton(n: number, overrides: Record<string, unknown> = {}) {
  return {
    uuid: `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
    name: `Imported Soup ${n}`,
    serves: 4,
    duration: 10,
    cookingDuration: 20,
    webLink: `https://example.com/soup-${n}`,
    tags: [{ name: "Chicken" }],
    ingredients: [
      { order: 0, ingredient: { name: "chicken broth" }, quantity: { quantityType: "CUP", amount: 4 } },
      { order: 1, ingredient: { name: "salt" } },
    ],
    steps: [
      { order: 0, step: "1. Heat the broth.", isSection: false },
      { order: 1, step: "2. Serve.", isSection: false },
    ],
    ...overrides,
  };
}

const importBatch = (recipes: unknown[], who: Who = "parent") => call(who, "recipes/import/crouton", "POST", { recipes });

async function recipeRows() {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  return db.select().from(schema.recipes);
}

const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 1)]);
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(100, 2)]);

function photo(data: Buffer, type = "image/jpeg", name = "photo.jpg") {
  const form = new FormData();
  form.set("file", new File([new Uint8Array(data)], name, { type }));
  return form;
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  await db.insert(schema.households).values([
    { id: "h1", name: "Mine", inviteCode: "A", guestInviteCode: "B" },
    { id: "h2", name: "Theirs", inviteCode: "C", guestInviteCode: "D" },
  ]);
  for (const who of ["parent", "guest"] as const) {
    const email = `${who}@example.com`;
    const created = await auth.api.signUpEmail({ body: { name: who, email, password } });
    const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
    cookies[who] = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    await db.insert(schema.householdMembers).values({ householdId: "h1", userId: created.user.id, role: who });
  }
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("importing from Crouton", () => {
  it("adds each recipe, and reports one that can't be read without losing the rest", async () => {
    const result = await importBatch([crouton(1), { name: "No id", ingredients: [], steps: [] }, crouton(2)]);
    expect(result.status).toBe(200);
    expect(result.json).toMatchObject({ created: 2, duplicates: 0, failed: 1 });
    expect(result.json.results.map((r) => [r.index, r.status])).toEqual([[0, "created"], [1, "failed"], [2, "created"]]);
    expect(result.json.results[1]).toMatchObject({ title: "No id" });
    expect(result.json.results[1].error).toContain("uuid");
    expect(result.json.results[0].id).toEqual(expect.any(String));
  });

  it("stores the mapped recipe, not Crouton's raw shape", async () => {
    const rows = await recipeRows();
    const row = rows.find((r) => r.title === "Imported Soup 1")!;
    expect(row).toMatchObject({
      householdId: "h1",
      servings: "4 servings",
      prepTime: "10 min",
      cookTime: "20 min",
      totalTime: "30 min",
      sourceUrl: "https://example.com/soup-1",
      importKey: "crouton:00000000-0000-4000-8000-000000000001",
      imageUrl: null,
    });
    expect(JSON.parse(row.ingredients)).toEqual(["4 cups chicken broth", "salt"]);
    expect(JSON.parse(row.directions)).toEqual(["Heat the broth.", "Serve."]);
    expect(JSON.parse(row.tags)).toEqual(["Chicken"]);
  });

  it("recognises what it already imported and adds nothing the second time", async () => {
    const before = (await recipeRows()).length;
    const again = await importBatch([crouton(1), crouton(2), crouton(3)]);
    expect(again.json).toMatchObject({ created: 1, duplicates: 2, failed: 0 });
    const duplicate = again.json.results.find((r) => r.status === "duplicate")!;
    expect(duplicate.id).toEqual(expect.any(String));
    expect((await recipeRows()).length).toBe(before + 1);
  });

  it("says whether a recipe it already has still needs its photo", async () => {
    // Imported earlier with no photo store set up, so no photo: the app is told to send one.
    const again = await importBatch([crouton(1), crouton(2)]);
    const first = again.json.results.find((r) => r.title === "Imported Soup 1")!;
    expect(first).toMatchObject({ status: "duplicate", hasPhoto: false });

    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    await db.update(schema.recipes).set({ imageUrl: "https://example.com/p.jpg" }).where(eq(schema.recipes.id, first.id!));
    const withPhoto = await importBatch([crouton(1), crouton(2)]);
    expect(withPhoto.json.results.find((r) => r.title === "Imported Soup 1")).toMatchObject({ status: "duplicate", hasPhoto: true });
    expect(withPhoto.json.results.find((r) => r.title === "Imported Soup 2")).toMatchObject({ status: "duplicate", hasPhoto: false });
  });

  it("treats the same recipe twice in one batch as one", async () => {
    const result = await importBatch([crouton(10), crouton(10)]);
    expect(result.json).toMatchObject({ created: 1, duplicates: 1 });
  });

  it("ends with one copy when two requests bring the same recipe at once", async () => {
    const [a, b] = await Promise.all([importBatch([crouton(20)]), importBatch([crouton(20)])]);
    expect(a.json.created + b.json.created).toBe(1);
    expect((await recipeRows()).filter((r) => r.title === "Imported Soup 20")).toHaveLength(1);
  });

  it("still imports a recipe whose title matches one added by hand, and two with the same title and different ids", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    await db.insert(schema.recipes).values({ id: crypto.randomUUID(), householdId: "h1", title: "Tacos" });
    const result = await importBatch([crouton(30, { name: "Tacos" }), crouton(31, { name: "Tacos" })]);
    expect(result.json.created).toBe(2);
  });

  it("keeps a heading, a very long step, and an amount range intact", async () => {
    const longStep = "Stir. ".repeat(250).trim();
    const result = await importBatch([
      crouton(40, {
        ingredients: [
          { order: 0, ingredient: { name: "Gravy" }, quantity: { quantityType: "SECTION" } },
          { order: 1, ingredient: { name: "broth" }, quantity: { quantityType: "CUP", amount: 5, secondaryAmount: 6 } },
        ],
        steps: [
          { order: 0, step: "Stove", isSection: true },
          { order: 1, step: longStep, isSection: false },
        ],
      }),
    ]);
    expect(result.json.created).toBe(1);
    const row = (await recipeRows()).find((r) => r.title === "Imported Soup 40")!;
    expect(JSON.parse(row.ingredients)).toEqual(["## Gravy", "5–6 cups broth"]);
    expect(JSON.parse(row.directions)).toEqual(["## Stove", longStep]);
    expect(longStep.length).toBeGreaterThan(1000);

    // And it can be edited afterwards: the edit route's limits must fit what was imported.
    const edited = await call("parent", "recipes/[id]", "PATCH", {
      title: "Imported Soup 40",
      ingredients: JSON.parse(row.ingredients),
      directions: JSON.parse(row.directions),
    }, { id: row.id });
    expect(edited.status).toBe(200);
  });

  it("keeps the import key private: it is not in the recipe list or the household export", async () => {
    const list = await call("parent", "recipes", "GET");
    expect(JSON.stringify(list.json)).not.toContain("importKey");
    expect(JSON.stringify(list.json)).not.toContain("crouton:");

    const { buildHouseholdExport } = await import("@/lib/household-export");
    const exported = await buildHouseholdExport("h1");
    expect(JSON.stringify(exported.recipes)).not.toContain("importKey");
  });

  it("refuses an empty batch, an oversized batch, and a body that isn't JSON", async () => {
    expect((await importBatch([])).status).toBe(400);
    const tooMany = await importBatch(Array.from({ length: 26 }, (_, index) => crouton(100 + index)));
    expect(tooMany.status).toBe(400);
    expect((await recipeRows()).some((r) => r.title === "Imported Soup 100")).toBe(false);
    const notJson = await call("parent", "recipes/import/crouton", "POST", {} as object);
    expect(notJson.status).toBe(400);
  });

  it("is for parents: a guest is refused and nothing is added, and signed-out callers are turned away", async () => {
    const before = (await recipeRows()).length;
    expect((await importBatch([crouton(50)], "guest")).status).toBe(403);
    expect((await importBatch([crouton(50)], "nobody")).status).toBe(401);
    expect((await recipeRows()).length).toBe(before);
  });

  it("allows many requests for a big export, then slows a runaway one", async () => {
    // 60 an hour; each carries up to 25 recipes. Earlier tests used some of them.
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    await db.delete(schema.rateLimits);
    let limited = 0;
    for (let attempt = 0; attempt < 62; attempt += 1) {
      const result = await importBatch([crouton(200 + attempt)]);
      if (result.status === 429) limited += 1;
    }
    expect(limited).toBe(2);
  });
});

describe("the unique index on import keys", () => {
  it("lets many recipes have no key, and refuses the same key twice in one household", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    await db.insert(schema.recipes).values([
      { id: crypto.randomUUID(), householdId: "h2", title: "A" },
      { id: crypto.randomUUID(), householdId: "h2", title: "B" },
    ]);
    await db.insert(schema.recipes).values({ id: crypto.randomUUID(), householdId: "h2", title: "C", importKey: "crouton:x" });
    await expect(
      db.insert(schema.recipes).values({ id: crypto.randomUUID(), householdId: "h2", title: "D", importKey: "crouton:x" }),
    ).rejects.toThrow();
    // Another household can import the same recipe.
    await db.insert(schema.recipes).values({ id: crypto.randomUUID(), householdId: "h1", title: "E", importKey: "crouton:x" });
  });
});

describe("recipe photos", () => {
  let recipeId = "";
  let otherHouseholdRecipe = "";

  beforeAll(async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    recipeId = crypto.randomUUID();
    otherHouseholdRecipe = crypto.randomUUID();
    await db.insert(schema.recipes).values([
      { id: recipeId, householdId: "h1", title: "Photographed" },
      { id: otherHouseholdRecipe, householdId: "h2", title: "Somebody else's" },
    ]);
  });

  beforeEach(() => {
    process.env.BLOB_READ_WRITE_TOKEN = "test-token";
    blob.put.mockReset().mockImplementation(async (pathname: string) => ({
      url: `https://abc123.public.blob.vercel-storage.com/${pathname.replace(/\/photo\./, "/photo-RANDOM.")}`,
    }));
    blob.del.mockReset().mockResolvedValue(undefined);
  });

  afterEach(() => {
    delete process.env.BLOB_READ_WRITE_TOKEN;
  });

  const upload = (who: Who, id: string, form: FormData) => call(who, "recipes/[id]/image", "POST", form, { id });

  it("stores the photo and points the recipe at it", async () => {
    const result = await upload("parent", recipeId, photo(JPEG));
    expect(result.status).toBe(200);
    expect(result.json.imageUrl).toBe(`https://abc123.public.blob.vercel-storage.com/recipes/h1/${recipeId}/photo-RANDOM.jpg`);
    const [pathname, , options] = blob.put.mock.calls[0];
    expect(pathname).toBe(`recipes/h1/${recipeId}/photo.jpg`);
    expect(options).toMatchObject({ access: "public", contentType: "image/jpeg", addRandomSuffix: true });
  });

  it("goes by what the file is, not what the app says it is", async () => {
    const result = await upload("parent", recipeId, photo(PNG, "image/jpeg", "actually.png"));
    expect(result.status).toBe(200);
    expect(blob.put.mock.calls[0][2]).toMatchObject({ contentType: "image/png" });
    expect(blob.put.mock.calls[0][0]).toMatch(/photo\.png$/);
  });

  it("replaces a photo it stored earlier and removes the old one", async () => {
    const first = await upload("parent", recipeId, photo(JPEG));
    const before = first.json.imageUrl as string;
    blob.del.mockClear();
    const second = await upload("parent", recipeId, photo(PNG, "image/png", "p.png"));
    expect(second.json.imageUrl).not.toBe(before);
    expect(blob.del).toHaveBeenCalledWith(before);
  });

  it("never deletes an image that lives on somebody else's website", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    await db.update(schema.recipes).set({ imageUrl: "https://example.com/their-photo.jpg" }).where(eq(schema.recipes.id, recipeId));
    blob.del.mockClear();
    const result = await upload("parent", recipeId, photo(JPEG));
    expect(result.status).toBe(200);
    expect(blob.del).not.toHaveBeenCalled();
  });

  it.each([
    ["a file that is not an image, whatever it claims", () => photo(Buffer.from("<html>hello</html>"), "image/jpeg")],
    ["a GIF", () => photo(Buffer.concat([Buffer.from("GIF89a"), Buffer.alloc(50)]), "image/gif", "a.gif")],
    ["an empty file", () => photo(Buffer.alloc(0))],
    ["a file over 5 MB", () => photo(Buffer.concat([JPEG, Buffer.alloc(5 * 1024 * 1024)]))],
  ])("refuses %s", async (_label, form) => {
    const result = await upload("parent", recipeId, form());
    expect(result.status).toBe(400);
    expect(blob.put).not.toHaveBeenCalled();
  });

  it("refuses a request with no file", async () => {
    const result = await upload("parent", recipeId, new FormData());
    expect(result.status).toBe(400);
    expect(result.json.error).toBe("Photo file is required.");
  });

  it("will not touch another household's recipe, and reports it as missing", async () => {
    const result = await upload("parent", otherHouseholdRecipe, photo(JPEG));
    expect(result.status).toBe(400);
    expect(result.json.error).toBe("Recipe not found.");
    expect(blob.put).not.toHaveBeenCalled();
  });

  it("is for parents", async () => {
    expect((await upload("guest", recipeId, photo(JPEG))).status).toBe(403);
    expect((await upload("nobody", recipeId, photo(JPEG))).status).toBe(401);
    expect(blob.put).not.toHaveBeenCalled();
  });

  it("says so, plainly, when photo storage isn't set up", async () => {
    delete process.env.BLOB_READ_WRITE_TOKEN;
    const result = await upload("parent", recipeId, photo(JPEG));
    expect(result.status).toBe(400);
    expect(result.json.error).toBe("Recipe photo uploads are not configured.");
  });
});
