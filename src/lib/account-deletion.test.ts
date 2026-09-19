import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "beacon-delete-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Client = typeof import("@/db/client");
type Schema = typeof import("@/db/schema");
type Deletion = typeof import("./account-deletion");
type Auth = typeof import("./auth");

let client: Client;
let schema: Schema;
let deletion: Deletion;
let authModule: Auth;
let counter = 0;

beforeAll(async () => {
  client = await import("@/db/client");
  schema = await import("@/db/schema");
  deletion = await import("./account-deletion");
  authModule = await import("./auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(client.db, { migrationsFolder: "drizzle" });
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

async function addUser(role?: "owner" | "parent" | "guest", householdId?: string) {
  const id = `u${++counter}`;
  const now = new Date();
  await client.db.insert(schema.users).values({
    id,
    name: `User ${id}`,
    email: `${id}@example.com`,
    createdAt: now,
    updatedAt: now,
  });
  if (role && householdId) {
    await client.db.insert(schema.householdMembers).values({ householdId, userId: id, role });
    await client.db
      .insert(schema.profiles)
      .values({ id: `p-${id}`, householdId, userId: id, name: `User ${id}`, profileType: "adult" });
  }
  return id;
}

async function addHousehold() {
  const id = `h${++counter}`;
  await client.db.insert(schema.households).values({
    id,
    name: id,
    inviteCode: `INV-${id}`,
    guestInviteCode: `GUEST-${id}`,
  });
  await client.db
    .insert(schema.groceryItems)
    .values({ id: `g-${id}`, householdId: id, title: "Milk" });
  await client.db
    .insert(schema.routines)
    .values({ id: `r-${id}`, householdId: id, name: "Morning", period: "morning" });
  return id;
}

async function count(table: "households" | "groceryItems" | "routines" | "profiles" | "householdMembers" | "users", column: string, value: string) {
  const { eq, sql } = await import("drizzle-orm");
  const t = schema[table] as unknown as Record<string, never>;
  const rows = await client.db
    .select({ n: sql<number>`count(*)` })
    .from(schema[table])
    .where(eq(t[column], value));
  return Number(rows[0].n);
}

describe("detachUserFromHouseholds", () => {
  it("deletes the whole household when the owner is its only member", async () => {
    const household = await addHousehold();
    const owner = await addUser("owner", household);

    await deletion.detachUserFromHouseholds(owner);

    expect(await count("households", "id", household)).toBe(0);
    expect(await count("groceryItems", "householdId", household)).toBe(0);
    expect(await count("routines", "householdId", household)).toBe(0);
    expect(await count("profiles", "householdId", household)).toBe(0);
  });

  it("blocks the only owner while other members remain, and changes nothing", async () => {
    const household = await addHousehold();
    const owner = await addUser("owner", household);
    await addUser("parent", household);

    await expect(deletion.detachUserFromHouseholds(owner)).rejects.toBeInstanceOf(
      deletion.AccountDeletionBlockedError,
    );
    expect(await count("households", "id", household)).toBe(1);
    expect(await count("householdMembers", "householdId", household)).toBe(2);
    expect(await count("profiles", "householdId", household)).toBe(2);
  });

  it("lets an owner leave when another owner exists", async () => {
    const household = await addHousehold();
    const owner = await addUser("owner", household);
    await addUser("owner", household);

    await deletion.detachUserFromHouseholds(owner);

    expect(await count("households", "id", household)).toBe(1);
    expect(await count("householdMembers", "householdId", household)).toBe(1);
  });

  it("removes only the leaving parent's membership and profile", async () => {
    const household = await addHousehold();
    await addUser("owner", household);
    const parent = await addUser("parent", household);

    await deletion.detachUserFromHouseholds(parent);

    expect(await count("households", "id", household)).toBe(1);
    expect(await count("householdMembers", "userId", parent)).toBe(0);
    expect(await count("profiles", "userId", parent)).toBe(0);
    expect(await count("profiles", "householdId", household)).toBe(1);
    expect(await count("groceryItems", "householdId", household)).toBe(1);
  });

  it("does nothing for a user who has no household", async () => {
    const loner = await addUser();
    await expect(deletion.detachUserFromHouseholds(loner)).resolves.toBeUndefined();
  });
});

describe("deleting an account through Better Auth", () => {
  async function signUp(email: string, password = "correct-horse-battery") {
    const { auth } = authModule;
    const created = await auth.api.signUpEmail({ body: { name: "Test", email, password } });
    const signedIn = await auth.api.signInEmail({
      body: { email, password },
      returnHeaders: true,
    });
    const cookie = signedIn.headers
      .getSetCookie()
      .map((value) => value.split(";")[0])
      .join("; ");
    return { userId: created.user.id, headers: new Headers({ cookie }) };
  }

  it("rejects a wrong password and keeps the account", async () => {
    const { userId, headers } = await signUp("wrong@example.com");
    await expect(
      authModule.auth.api.deleteUser({ body: { password: "not-the-password" }, headers }),
    ).rejects.toThrow();
    expect(await count("users", "id", userId)).toBe(1);
  });

  it("deletes the account and the user's household data with the right password", async () => {
    const { userId, headers } = await signUp("owner@example.com");
    const household = await addHousehold();
    await client.db
      .insert(schema.householdMembers)
      .values({ householdId: household, userId, role: "owner" });

    await authModule.auth.api.deleteUser({
      body: { password: "correct-horse-battery" },
      headers,
    });

    expect(await count("users", "id", userId)).toBe(0);
    expect(await count("households", "id", household)).toBe(0);
    expect(await count("groceryItems", "householdId", household)).toBe(0);
  });

  it("refuses the only owner of a shared household with a helpful message", async () => {
    const { userId, headers } = await signUp("blocked@example.com");
    const household = await addHousehold();
    await client.db
      .insert(schema.householdMembers)
      .values({ householdId: household, userId, role: "owner" });
    await addUser("parent", household);

    await expect(
      authModule.auth.api.deleteUser({ body: { password: "correct-horse-battery" }, headers }),
    ).rejects.toMatchObject({ body: { message: expect.stringContaining("only owner") } });

    expect(await count("users", "id", userId)).toBe(1);
    expect(await count("households", "id", household)).toBe(1);
  });
});
