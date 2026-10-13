import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "beacon-members-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";

const userIds: string[] = [];

async function ownersOf(householdId: string) {
  const { db } = await import("@/db/client");
  const { householdMembers } = await import("@/db/schema");
  const { eq } = await import("drizzle-orm");
  const rows = await db.select().from(householdMembers).where(eq(householdMembers.householdId, householdId));
  return rows.filter((row) => row.role === "owner").length;
}

async function setup(householdId: string, roles: Array<"owner" | "parent" | "guest">) {
  const { db } = await import("@/db/client");
  const { households, householdMembers } = await import("@/db/schema");
  await db.insert(households).values({ id: householdId, name: householdId, inviteCode: `I-${householdId}`, guestInviteCode: `G-${householdId}` });
  const ids: string[] = [];
  for (const [index, role] of roles.entries()) {
    const userId = userIds[index];
    await db.insert(householdMembers).values({ householdId, userId, role });
    ids.push(userId);
  }
  return ids;
}

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const schema = await import("@/db/schema");
  const { auth } = await import("@/lib/auth");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  for (const name of ["a", "b", "c"]) {
    const created = await auth.api.signUpEmail({
      body: { name, email: `${name}@example.com`, password: "correct-horse-battery" },
    });
    userIds.push(created.user.id);
  }
  void schema;
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("changing a member's role", () => {
  it("lets one of two owners step the other down", async () => {
    const { updateHouseholdMemberRole } = await import("./household-members");
    const [a, b] = await setup("h-one", ["owner", "owner"]);
    const role = await updateHouseholdMemberRole({ householdId: "h-one", actorUserId: a, actorRole: "owner", targetUserId: b, nextRole: "parent" });
    expect(role).toBe("parent");
    expect(await ownersOf("h-one")).toBe(1);
  });

  it("never leaves a household with no owner when two owners demote each other at once", async () => {
    const { updateHouseholdMemberRole } = await import("./household-members");
    const [a, b] = await setup("h-race", ["owner", "owner"]);
    const results = await Promise.allSettled([
      updateHouseholdMemberRole({ householdId: "h-race", actorUserId: a, actorRole: "owner", targetUserId: b, nextRole: "parent" }),
      updateHouseholdMemberRole({ householdId: "h-race", actorUserId: b, actorRole: "owner", targetUserId: a, nextRole: "parent" }),
    ]);
    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    const rejected = results.find((result) => result.status === "rejected") as PromiseRejectedResult;
    expect(String(rejected.reason)).toContain("at least one owner");
    expect(await ownersOf("h-race")).toBe(1);
  });

  it("still refuses to demote the only owner", async () => {
    const { updateHouseholdMemberRole } = await import("./household-members");
    const [a, b] = await setup("h-solo", ["owner", "parent"]);
    // The parent cannot do it; the rule is checked before the update runs.
    await expect(
      updateHouseholdMemberRole({ householdId: "h-solo", actorUserId: b, actorRole: "parent", targetUserId: a, nextRole: "parent" }),
    ).rejects.toThrow();
    expect(await ownersOf("h-solo")).toBe(1);
  });

  it("changes a parent to a guest as before", async () => {
    const { updateHouseholdMemberRole } = await import("./household-members");
    const [a, , c] = await setup("h-guest", ["owner", "parent", "parent"]);
    expect(
      await updateHouseholdMemberRole({ householdId: "h-guest", actorUserId: a, actorRole: "owner", targetUserId: c, nextRole: "guest" }),
    ).toBe("guest");
  });

  it("refuses a delayed demotion after the target becomes the sole owner", async () => {
    const { db } = await import("@/db/client");
    const { householdMembers } = await import("@/db/schema");
    const { eq } = await import("drizzle-orm");
    const { updateHouseholdMemberRole: change } = await import("./household-members");
    const [a, b] = await setup("h-promoted", ["owner", "parent"]);
    const snapshot = await db.select({ userId: householdMembers.userId, role: householdMembers.role })
      .from(householdMembers).where(eq(householdMembers.householdId, "h-promoted"));
    let release!: () => void;
    let started!: () => void;
    const gate = new Promise<void>((resolve) => { release = resolve; });
    const read = new Promise<void>((resolve) => { started = resolve; });
    const spy = vi.spyOn(db, "select").mockReturnValueOnce({
      from: () => ({ where: async () => { started(); await gate; return snapshot; } }),
    } as never);
    const delayed = change({ householdId: "h-promoted", actorUserId: a, actorRole: "owner", targetUserId: b, nextRole: "guest" });
    const result = delayed.then(() => null, (error: Error) => error);
    await read;
    await change({ householdId: "h-promoted", actorUserId: a, actorRole: "owner", targetUserId: b, nextRole: "owner" });
    await change({ householdId: "h-promoted", actorUserId: b, actorRole: "owner", targetUserId: a, nextRole: "parent" });
    release();
    expect(await result).toBeInstanceOf(Error);
    expect(await ownersOf("h-promoted")).toBe(1);
    spy.mockRestore();
  });

  it("does not trust an actor role captured before their access was removed", async () => {
    const { updateHouseholdMemberRole } = await import("./household-members");
    const [a, b] = await setup("h-stale-actor", ["guest", "owner"]);
    await expect(updateHouseholdMemberRole({ householdId: "h-stale-actor", actorUserId: a,
      actorRole: "owner", targetUserId: b, nextRole: "guest" })).rejects.toThrow("permission");
    expect(await ownersOf("h-stale-actor")).toBe(1);
  });
});
