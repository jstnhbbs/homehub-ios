import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const request = vi.hoisted(() => ({ headers: new Headers() }));
vi.mock("next/headers", () => ({
  headers: async () => request.headers,
  cookies: async () => ({ get: () => undefined, getAll: () => [] }),
}));

const dir = mkdtempSync(path.join(tmpdir(), "beacon-join-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

type Handler = (request: Request, context: { params: Promise<Record<string, string>> }) => Promise<Response>;

const password = "correct-horse-battery";
const cookies: Record<string, string> = {};

async function signUp(name: string) {
  const { auth } = await import("@/lib/auth");
  const email = `${name}@example.com`;
  const created = await auth.api.signUpEmail({ body: { name, email, password } });
  const signedIn = await auth.api.signInEmail({ body: { email, password }, returnHeaders: true });
  cookies[name] = signedIn.headers
    .getSetCookie()
    .map((value) => value.split(";")[0])
    .join("; ");
  return created.user.id;
}

async function post(who: string, route: string, body: unknown, extraHeaders: Record<string, string> = {}) {
  request.headers = new Headers({ cookie: cookies[who] });
  const routeModule = (await import(/* @vite-ignore */ `@/app/api/mobile/v1/${route}/route`)) as Record<string, Handler>;
  const response = await routeModule.POST(
    new Request(`http://localhost:3000/api/mobile/v1/${route}`, {
      method: "POST",
      headers: { "content-type": "application/json", ...extraHeaders },
      body: JSON.stringify(body),
    }),
    { params: Promise.resolve({}) },
  );
  return { status: response.status, json: (await response.json()) as Record<string, unknown> };
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });

  // One household from before the longer codes (8 hex characters) and one with the new kind.
  await db.insert(schema.households).values([
    { id: "old", name: "Old", inviteCode: "A1B2C3D4", guestInviteCode: "E5F6A7B8" },
    { id: "new", name: "New", inviteCode: "KQ7M2XW9HP", guestInviteCode: "TR4N8ZC3VD" },
  ]);
  const owner = await signUp("owner");
  await db.insert(schema.householdMembers).values({ householdId: "old", userId: owner, role: "owner" });
  for (const name of ["ann", "bob", "cy", "dee", "eli", "flo", "guy", "hal", "ivy", "jon", "kim", "zed", "yan", "xia", "una"]) {
    await signUp(name);
  }
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("invite codes", () => {
  it("makes 10-character codes from an alphabet without look-alikes, and two that differ", async () => {
    const { generateInviteCode, generateInviteCodePair } = await import("@/lib/invite-codes");
    for (let index = 0; index < 200; index += 1) {
      expect(generateInviteCode()).toMatch(/^[A-HJ-NP-Z2-9]{10}$/);
    }
    const pair = generateInviteCodePair();
    expect(pair.inviteCode).not.toBe(pair.guestInviteCode);
  });

  it("cleans up what a person typed", async () => {
    const { normalizeInviteCode } = await import("@/lib/invite-codes");
    expect(normalizeInviteCode("  kq7m2-xw9hp \n")).toBe("KQ7M2XW9HP");
    expect(normalizeInviteCode("a1b2 c3d4")).toBe("A1B2C3D4");
  });

  it("reads the caller's address from the proxy header", async () => {
    const { clientAddress } = await import("@/lib/invite-codes");
    expect(clientAddress(new Headers({ "x-forwarded-for": "203.0.113.9, 10.0.0.1" }))).toBe("203.0.113.9");
    expect(clientAddress(new Headers({ "x-real-ip": "203.0.113.7" }))).toBe("203.0.113.7");
    expect(clientAddress(new Headers())).toBeNull();
  });
});

describe("joining a household", () => {
  it("still accepts a code from before the change, however it is typed", async () => {
    const joined = await post("ann", "household/join", { inviteCode: " a1b2-c3d4 " });
    expect(joined.status).toBe(200);
    expect(joined.json.role).toBe("parent");
    expect(joined.json.name).toBe("Old");
  });

  it("accepts a new-style guest code and makes the person a guest", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    await db.insert(schema.householdMembers).values({
      householdId: "new",
      userId: (await db.select().from(schema.users)).find((user) => user.email === "owner@example.com")!.id,
      role: "owner",
    });
    const joined = await post("bob", "household/join-guest", { guestInviteCode: "tr4n8-zc3vd" });
    expect(joined.status).toBe(200);
    expect(joined.json.role).toBe("guest");
    // The guest sees neither code.
    expect(joined.json.inviteCode).toBe("");
    expect(joined.json.guestInviteCode).toBe("");
  });

  it("lets someone use their own household's code again, but not join a second household", async () => {
    // ann joined "old" above.
    const again = await post("ann", "household/join", { inviteCode: "A1B2C3D4" });
    expect(again.status).toBe(200);
    expect(again.json.name).toBe("Old");

    const other = await post("ann", "household/join", { inviteCode: "KQ7M2XW9HP" });
    expect(other.status).toBe(400);
    expect(String(other.json.error)).toContain("already belong to a household");
    const asGuest = await post("ann", "household/join-guest", { guestInviteCode: "TR4N8ZC3VD" });
    expect(asGuest.status).toBe(400);

    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    const memberships = await db
      .select()
      .from(schema.householdMembers)
      .where(eq(schema.householdMembers.householdId, "new"));
    expect(memberships.some((member) => member.role === "parent")).toBe(false);
  });

  it("answers a wrong code with 400 and a plain message", async () => {
    const wrong = await post("cy", "household/join", { inviteCode: "ZZZZZZZZZZ" });
    expect(wrong.status).toBe(400);
    expect(wrong.json.error).toBe("That invite code was not found.");
  });

  it("explains a missing code instead of dumping a validation object", async () => {
    const missing = await post("cy", "household/join", {});
    expect(missing.status).toBe(400);
    expect(String(missing.json.error)).toContain("inviteCode");
    expect(String(missing.json.error)).not.toContain("[{");
  });

  it("stops one account guessing: ten tries, then 429, and a wrong guess never opens the door", async () => {
    // cy already used 2 tries above.
    for (let attempt = 0; attempt < 8; attempt += 1) {
      const guess = await post("cy", "household/join", { inviteCode: `GUESS${attempt}AAAA` });
      expect(guess.status).toBe(400);
    }
    const blocked = await post("cy", "household/join", { inviteCode: "KQ7M2XW9HP" });
    // Even the right code is refused once the limit is hit.
    expect(blocked.status).toBe(429);
    expect(String(blocked.json.error)).toContain("Too many");
  });

  it("does not let one account's tries use up another's", async () => {
    const other = await post("dee", "household/join", { inviteCode: "KQ7M2XW9HP" });
    expect(other.status).toBe(200);
  });

  it("also limits by address, across accounts, for guest codes too", async () => {
    const headers = { "x-forwarded-for": "198.51.100.23" };
    // Seven accounts, so no single account reaches its own limit of ten before the address does.
    const names = ["eli", "flo", "guy", "hal", "ivy", "jon", "kim"];
    let blockedAt = -1;
    for (let attempt = 0; attempt < 45; attempt += 1) {
      const result = await post(
        names[attempt % names.length],
        "household/join-guest",
        { guestInviteCode: `NOPE${attempt}NOPE` },
        headers,
      );
      if (result.status === 429) {
        blockedAt = attempt;
        break;
      }
    }
    // 40 tries per address per hour; the 41st is refused.
    expect(blockedAt).toBe(40);
  });
});

describe("starting a household", () => {
  const start = (who: string, timezone: string) =>
    post(who, "household", { name: "Una's", ownerLastName: "Una", timezone });

  it("refuses a time zone the server doesn't know, which would break every later request", async () => {
    const result = await start("una", "Mars/Olympus_Mons");
    expect(result.status).toBe(400);
    expect(String(result.json.error)).toContain("time zone");
  });

  it("starts one for someone with none, and refuses a second", async () => {
    const first = await start("una", "America/Chicago");
    expect(first.status).toBe(201);
    expect(first.json.role).toBe("owner");
    const second = await start("una", "America/Chicago");
    expect(second.status).toBe(400);
    expect(String(second.json.error)).toContain("already belong to a household");
  });
});

describe("regenerating invite codes", () => {
  const regenerate = (who: string, which: unknown) => post(who, "household/invite-codes", { which });

  async function codes(householdId: string) {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    const [row] = await db.select().from(schema.households).where(eq(schema.households.id, householdId));
    return { parent: row.inviteCode, guest: row.guestInviteCode };
  }

  it("replaces the parent code, which stops the old one working and leaves the guest code alone", async () => {
    const before = await codes("old");
    const result = await regenerate("owner", "parent");
    expect(result.status).toBe(200);
    expect(result.json.inviteCode).toMatch(/^[A-HJ-NP-Z2-9]{10}$/);
    expect(result.json.inviteCode).not.toBe(before.parent);
    expect(result.json.guestInviteCode).toBe(before.guest);

    const now = await codes("old");
    expect(now.parent).toBe(result.json.inviteCode);
    expect(now.guest).toBe(before.guest);

    const old = await post("zed", "household/join", { inviteCode: before.parent });
    expect(old.status).toBe(400);
    expect(old.json.error).toBe("That invite code was not found.");
    const fresh = await post("zed", "household/join", { inviteCode: now.parent });
    expect(fresh.status).toBe(200);
    expect(fresh.json.role).toBe("parent");
  });

  it("replaces only the guest code when asked", async () => {
    const before = await codes("old");
    const result = await regenerate("owner", "guest");
    expect(result.json.guestInviteCode).not.toBe(before.guest);
    expect(result.json.guestInviteCode).toMatch(/^[A-HJ-NP-Z2-9]{10}$/);
    expect(result.json.inviteCode).toBe(before.parent);

    expect((await post("yan", "household/join-guest", { guestInviteCode: before.guest })).status).toBe(400);
    const joined = await post("yan", "household/join-guest", { guestInviteCode: result.json.guestInviteCode });
    expect(joined.status).toBe(200);
    expect(joined.json.role).toBe("guest");
  });

  it("replaces both, as two different codes", async () => {
    const before = await codes("old");
    const result = await regenerate("owner", "both");
    expect(result.status).toBe(200);
    expect(result.json.inviteCode).not.toBe(before.parent);
    expect(result.json.guestInviteCode).not.toBe(before.guest);
    expect(result.json.inviteCode).not.toBe(result.json.guestInviteCode);
  });

  it("leaves people who are already members exactly as they were", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    const members = () => db.select().from(schema.householdMembers).where(eq(schema.householdMembers.householdId, "old"));
    const before = (await members()).map((member) => `${member.userId}:${member.role}`).sort();
    await regenerate("owner", "both");
    expect((await members()).map((member) => `${member.userId}:${member.role}`).sort()).toEqual(before);
  });

  it("works for a parent as well as the owner, and only changes its own household", async () => {
    const other = await codes("new");
    const result = await regenerate("ann", "parent");
    expect(result.status).toBe(200);
    expect(await codes("new")).toEqual(other);
  });

  it("is refused for a guest, and the codes do not change", async () => {
    const before = await codes("new");
    const result = await regenerate("bob", "both");
    expect(result.status).toBe(403);
    expect(await codes("new")).toEqual(before);
  });

  it("refuses a request that doesn't say which code", async () => {
    expect((await regenerate("owner", "everything")).status).toBe(400);
    expect((await post("owner", "household/invite-codes", {})).status).toBe(400);
  });

  it("slows down someone changing codes over and over", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    await db.delete(schema.rateLimits);
    let limited = 0;
    for (let attempt = 0; attempt < 12; attempt += 1) {
      if ((await regenerate("owner", "guest")).status === 429) limited += 1;
    }
    expect(limited).toBe(2);
  });
});

describe("profiles for members", () => {
  async function profileFor(email: string) {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const users = await db.select().from(schema.users);
    const userId = users.find((user) => user.email === email)!.id;
    const profiles = await db.select().from(schema.profiles);
    return profiles.filter((profile) => profile.userId === userId);
  }

  it("are made when someone joins, not on their first later request", async () => {
    const parent = await post("xia", "household/join", { inviteCode: (await codesFor("new")).parent });
    expect(parent.status).toBe(200);
    expect(await profileFor("xia@example.com")).toHaveLength(1);
  });

  it("are still repaired for a member who has none", async () => {
    const { db } = await import("@/db/client");
    const schema = await import("@/db/schema");
    const { and, eq } = await import("drizzle-orm");
    const [profile] = await profileFor("xia@example.com");
    await db.delete(schema.profiles).where(and(eq(schema.profiles.id, profile.id)));
    expect(await profileFor("xia@example.com")).toHaveLength(0);

    const { json } = await (async () => {
      request.headers = new Headers({ cookie: cookies.xia });
      const route = (await import("@/app/api/mobile/v1/profiles/route")) as { GET: () => Promise<Response> };
      const response = await route.GET();
      return { json: await response.json() };
    })();
    expect(Array.isArray(json)).toBe(true);
    expect(await profileFor("xia@example.com")).toHaveLength(1);
  });

  it("are not duplicated by ordinary requests", async () => {
    for (let index = 0; index < 3; index += 1) {
      request.headers = new Headers({ cookie: cookies.xia });
      const route = (await import("@/app/api/mobile/v1/profiles/route")) as { GET: () => Promise<Response> };
      await route.GET();
    }
    expect(await profileFor("xia@example.com")).toHaveLength(1);
  });
});

async function codesFor(householdId: string) {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { eq } = await import("drizzle-orm");
  const [row] = await db.select().from(schema.households).where(eq(schema.households.id, householdId));
  return { parent: row.inviteCode, guest: row.guestInviteCode };
}
