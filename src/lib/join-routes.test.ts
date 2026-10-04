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
  for (const name of ["ann", "bob", "cy", "dee", "eli", "flo", "guy", "hal", "ivy", "jon", "kim"]) {
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
