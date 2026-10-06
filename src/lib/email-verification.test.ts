import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

// Sign-up, the email, following its link, and what an unverified address can still do, run against
// the real Better Auth and a throwaway database. Nothing here talks to a mail provider.

const dir = mkdtempSync(path.join(tmpdir(), "beacon-verify-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;
process.env.BETTER_AUTH_SECRET = "test-secret-that-is-long-enough-for-better-auth";
process.env.BETTER_AUTH_URL = "http://localhost:3000";
process.env.DISABLE_AUTH_RATE_LIMIT = "true";

const password = "correct-horse-battery";

type Modules = {
  auth: typeof import("@/lib/auth").auth;
  outbox: typeof import("@/lib/email").outbox;
  db: typeof import("@/db/client").db;
  users: typeof import("@/db/schema").users;
  eq: typeof import("drizzle-orm").eq;
};
let m: Modules;

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const { users } = await import("@/db/schema");
  const { eq } = await import("drizzle-orm");
  const { auth } = await import("@/lib/auth");
  const { outbox } = await import("@/lib/email");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  m = { auth, outbox, db, users, eq };
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

async function verified(email: string) {
  const [row] = await m.db.select().from(m.users).where(m.eq(m.users.email, email));
  return row.emailVerified;
}

function tokenFrom(text: string) {
  const link = text.split("\n").find((line) => line.includes("/api/auth/verify-email"))!;
  return { link, token: new URL(link).searchParams.get("token")! };
}

describe("email verification", () => {
  it("sends one email at sign-up, to that address, with a link", async () => {
    m.outbox.length = 0;
    await m.auth.api.signUpEmail({ body: { name: "Pat", email: "pat@example.com", password } });

    expect(m.outbox).toHaveLength(1);
    const email = m.outbox[0];
    expect(email.to).toBe("pat@example.com");
    expect(email.subject).toBe("Confirm your email for Beacon");
    const { link } = tokenFrom(email.text);
    expect(new URL(link).origin).toBe("http://localhost:3000");
    expect(new URL(link).searchParams.get("callbackURL")).toBe("/email-verified");
  });

  it("leaves the address unverified until the link is followed, and does not block sign-in meanwhile", async () => {
    expect(await verified("pat@example.com")).toBe(false);
    const signedIn = await m.auth.api.signInEmail({ body: { email: "pat@example.com", password } });
    expect(signedIn.user.email).toBe("pat@example.com");
    expect(signedIn.user.emailVerified).toBe(false);
  });

  it("verifies the address when the link is followed", async () => {
    const { token } = tokenFrom(m.outbox[0].text);
    await m.auth.api.verifyEmail({ query: { token } });
    expect(await verified("pat@example.com")).toBe(true);
  });

  it("does not sign anyone in by following the link", async () => {
    m.outbox.length = 0;
    await m.auth.api.signUpEmail({ body: { name: "Lee", email: "lee@example.com", password } });
    const { token } = tokenFrom(m.outbox[0].text);
    const result = await m.auth.api.verifyEmail({ query: { token }, returnHeaders: true });
    const cookies = result.headers.getSetCookie().join(";");
    expect(cookies).not.toContain("session_token");
    expect(await verified("lee@example.com")).toBe(true);
  });

  it("rejects a token that was made up", async () => {
    await expect(m.auth.api.verifyEmail({ query: { token: "not-a-real-token" } })).rejects.toThrow();
  });

  it("rejects a token for an address that has since changed hands", async () => {
    m.outbox.length = 0;
    await m.auth.api.signUpEmail({ body: { name: "Sam", email: "sam@example.com", password } });
    const { token } = tokenFrom(m.outbox[0].text);
    const tampered = token.slice(0, -2) + (token.endsWith("aa") ? "bb" : "aa");
    await expect(m.auth.api.verifyEmail({ query: { token: tampered } })).rejects.toThrow();
    expect(await verified("sam@example.com")).toBe(false);
  });

  it("sends a fresh link on request", async () => {
    m.outbox.length = 0;
    await m.auth.api.sendVerificationEmail({ body: { email: "sam@example.com", callbackURL: "/email-verified" } });
    expect(m.outbox).toHaveLength(1);
    expect(m.outbox[0].to).toBe("sam@example.com");
    const { token } = tokenFrom(m.outbox[0].text);
    await m.auth.api.verifyEmail({ query: { token } });
    expect(await verified("sam@example.com")).toBe(true);
  });

  it("sends nothing for an address that is not an account, and does not say so", async () => {
    m.outbox.length = 0;
    const result = await m.auth.api.sendVerificationEmail({ body: { email: "nobody@example.com" } });
    expect(m.outbox).toHaveLength(0);
    // The same answer as for a real account, so the form cannot be used to find out who has one.
    expect(result.status).toBe(true);
  });

  it("does not send again for an address already verified", async () => {
    m.outbox.length = 0;
    await m.auth.api.sendVerificationEmail({ body: { email: "pat@example.com" } }).catch(() => {});
    expect(m.outbox).toHaveLength(0);
  });
});
