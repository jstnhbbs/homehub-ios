import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "beacon-ratelimit-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;

const window = { limit: 10, windowMs: 60_000 };
let checkRateLimit: typeof import("@/lib/rate-limit").checkRateLimit;
let counter = 0;
/** A scope no other test uses, so tests never share a count. */
const fresh = () => `scope-${counter++}`;

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  await migrate(db, { migrationsFolder: "drizzle" });
  ({ checkRateLimit } = await import("@/lib/rate-limit"));
});

afterEach(() => {
  vi.useRealTimers();
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

describe("checkRateLimit", () => {
  it("allows the first `limit` requests and refuses the rest", async () => {
    const scope = fresh();
    const results: boolean[] = [];
    for (let attempt = 0; attempt < 14; attempt += 1) results.push(await checkRateLimit(scope, "me", window));
    expect(results.filter(Boolean)).toHaveLength(10);
    expect(results.slice(0, 10).every(Boolean)).toBe(true);
    expect(results.slice(10).some(Boolean)).toBe(false);
  });

  it("holds the line when many requests arrive at the same moment", async () => {
    // The old read-then-write version let a burst through: every request read the same low count.
    const scope = fresh();
    const results = await Promise.all(Array.from({ length: 50 }, () => checkRateLimit(scope, "burst", window)));
    expect(results.filter(Boolean)).toHaveLength(10);
  });

  it("holds the line across several simultaneous bursts too", async () => {
    const scope = fresh();
    let allowed = 0;
    for (let round = 0; round < 3; round += 1) {
      const results = await Promise.all(Array.from({ length: 20 }, () => checkRateLimit(scope, "rounds", window)));
      allowed += results.filter(Boolean).length;
    }
    expect(allowed).toBe(10);
  });

  it("counts each person and each scope separately", async () => {
    const scope = fresh();
    for (let attempt = 0; attempt < 10; attempt += 1) await checkRateLimit(scope, "ann", window);
    expect(await checkRateLimit(scope, "ann", window)).toBe(false);
    expect(await checkRateLimit(scope, "bob", window)).toBe(true);
    expect(await checkRateLimit(fresh(), "ann", window)).toBe(true);
  });

  it("starts a new window once the old one has passed, and not before", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-10-04T12:00:00Z"));
    const scope = fresh();
    for (let attempt = 0; attempt < 10; attempt += 1) await checkRateLimit(scope, "me", window);
    expect(await checkRateLimit(scope, "me", window)).toBe(false);

    vi.setSystemTime(new Date("2026-10-04T12:00:59Z"));
    expect(await checkRateLimit(scope, "me", window)).toBe(false);

    vi.setSystemTime(new Date("2026-10-04T12:01:00Z"));
    expect(await checkRateLimit(scope, "me", window)).toBe(true);
    // A fresh window gives a full allowance again, not just one request.
    const results: boolean[] = [];
    for (let attempt = 0; attempt < 12; attempt += 1) results.push(await checkRateLimit(scope, "me", window));
    expect(results.filter(Boolean)).toHaveLength(9);
  });

  it("does not stretch the window by refusing requests inside it", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-10-04T12:00:00Z"));
    const scope = fresh();
    for (let attempt = 0; attempt < 10; attempt += 1) await checkRateLimit(scope, "me", window);
    // Keep hammering for a while; the window still ends a minute after the first request.
    for (let second = 5; second < 55; second += 10) {
      vi.setSystemTime(new Date(`2026-10-04T12:00:${String(second).padStart(2, "0")}Z`));
      expect(await checkRateLimit(scope, "me", window)).toBe(false);
    }
    vi.setSystemTime(new Date("2026-10-04T12:01:00Z"));
    expect(await checkRateLimit(scope, "me", window)).toBe(true);
  });

  it("works with a limit of one", async () => {
    const scope = fresh();
    const one = { limit: 1, windowMs: 60_000 };
    expect(await checkRateLimit(scope, "me", one)).toBe(true);
    expect(await checkRateLimit(scope, "me", one)).toBe(false);
  });
});
