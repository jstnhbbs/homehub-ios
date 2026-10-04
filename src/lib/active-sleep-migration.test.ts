import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { createClient, type Client } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import { migrate } from "drizzle-orm/libsql/migrator";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

// Migration 0026 adds a unique index on running sleeps. Production may already hold a child with
// two running sleeps, and creating the index over them would fail the deploy, so the migration has
// to repair them first. This builds the database as it was before 0026, makes that mess, then
// applies 0026 the way a deploy does.

const dir = mkdtempSync(path.join(tmpdir(), "beacon-active-sleep-"));
const folder = path.join(dir, "drizzle");
let client: Client;

const at = (iso: string) => Math.floor(new Date(iso).getTime() / 1000);

async function rows(sql: string) {
  return (await client.execute(sql)).rows.map((row) => ({ ...row }));
}

beforeAll(async () => {
  cpSync(path.resolve("drizzle"), folder, { recursive: true });
  const journalPath = path.join(folder, "meta/_journal.json");
  const journal = JSON.parse(readFileSync(journalPath, "utf8")) as { entries: Array<{ tag: string }> };
  const last = journal.entries.at(-1)!;
  expect(last.tag).toBe("0026_one_active_sleep_per_child");

  // The database as it stood before 0026.
  writeFileSync(journalPath, JSON.stringify({ ...journal, entries: journal.entries.slice(0, -1) }));
  client = createClient({ url: `file:${path.join(dir, "test.db")}` });
  await migrate(drizzle(client), { migrationsFolder: folder });

  await client.execute("insert into households (id, name, invite_code, guest_invite_code, created_at, updated_at) values ('h', 'H', 'A', 'B', 0, 0)");
  for (const id of ["p1", "p2", "p3"]) {
    await client.execute({
      sql: "insert into profiles (id, household_id, profile_type, name, color, sort_order, created_at, updated_at) values (?, 'h', 'child', ?, '#fff', 0, 0, 0)",
      args: [id, id],
    });
  }
  const log = (id: string, profile: string, started: string, ended: string | null, kind = "nap") =>
    client.execute({
      sql: "insert into nap_logs (id, household_id, profile_id, kind, local_date, started_at, ended_at, created_at, updated_at) values (?, 'h', ?, ?, '2026-10-04', ?, ?, 0, 0)",
      args: [id, profile, kind, at(started), ended ? at(ended) : null],
    });

  // p1: three running sleeps, the mess a race leaves behind.
  await log("p1-old", "p1", "2026-10-04T08:00:00Z", null);
  await log("p1-mid", "p1", "2026-10-04T10:00:00Z", null, "night");
  await log("p1-new", "p1", "2026-10-04T12:00:00Z", null);
  // p1 also has ordinary finished sleeps, which must be left alone.
  await log("p1-done", "p1", "2026-10-03T08:00:00Z", "2026-10-03T09:00:00Z");
  // p2: exactly one running sleep, nothing to repair.
  await log("p2-live", "p2", "2026-10-04T09:00:00Z", null);
  // p3: two running sleeps that began at the same instant; the id breaks the tie.
  await log("p3-a", "p3", "2026-10-04T07:00:00Z", null);
  await log("p3-b", "p3", "2026-10-04T07:00:00Z", null);

  // Now apply 0026, as a deploy would.
  cpSync(path.resolve("drizzle/meta/_journal.json"), journalPath);
  await migrate(drizzle(client), { migrationsFolder: folder });
});

afterAll(() => {
  client.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("migration 0026", () => {
  it("leaves each child with at most one running sleep, the newest", async () => {
    const running = await rows("select id, profile_id from nap_logs where ended_at is null order by profile_id");
    expect(running).toEqual([
      { id: "p1-new", profile_id: "p1" },
      { id: "p2-live", profile_id: "p2" },
      { id: "p3-b", profile_id: "p3" },
    ]);
  });

  it("ends each older running sleep when the next one began", async () => {
    const byId = Object.fromEntries((await rows("select id, ended_at from nap_logs")).map((row) => [row.id, row.ended_at]));
    expect(byId["p1-old"]).toBe(at("2026-10-04T10:00:00Z")); // ended when p1-mid began
    expect(byId["p1-mid"]).toBe(at("2026-10-04T12:00:00Z")); // ended when p1-new began
    expect(byId["p3-a"]).toBe(at("2026-10-04T07:00:00Z")); // same instant: a zero-length entry, still closed
  });

  it("does not touch sleeps that were fine", async () => {
    const byId = Object.fromEntries((await rows("select id, ended_at from nap_logs")).map((row) => [row.id, row.ended_at]));
    expect(byId["p1-done"]).toBe(at("2026-10-03T09:00:00Z"));
    expect(byId["p2-live"]).toBeNull();
    expect(byId["p1-new"]).toBeNull();
  });

  it("has the index, and it refuses a second running sleep for a child", async () => {
    const index = await rows("select name from sqlite_master where type = 'index' and name = 'nap_logs_one_active_per_profile_idx'");
    expect(index).toHaveLength(1);

    await expect(
      client.execute("insert into nap_logs (id, household_id, profile_id, kind, local_date, started_at, created_at, updated_at) values ('dup', 'h', 'p2', 'nap', '2026-10-04', 1, 0, 0)"),
    ).rejects.toThrow(/nap_logs\.profile_id/);
  });

  it("still allows many finished sleeps, and one running sleep for a child with none", async () => {
    await client.execute("insert into nap_logs (id, household_id, profile_id, kind, local_date, started_at, ended_at, created_at, updated_at) values ('f1', 'h', 'p2', 'nap', '2026-10-02', 1, 2, 0, 0)");
    await client.execute("insert into nap_logs (id, household_id, profile_id, kind, local_date, started_at, ended_at, created_at, updated_at) values ('f2', 'h', 'p2', 'nap', '2026-10-02', 3, 4, 0, 0)");
    await client.execute("insert into profiles (id, household_id, profile_type, name, color, sort_order, created_at, updated_at) values ('p4', 'h', 'child', 'p4', '#fff', 0, 0, 0)");
    await client.execute("insert into nap_logs (id, household_id, profile_id, kind, local_date, started_at, created_at, updated_at) values ('p4-live', 'h', 'p4', 'nap', '2026-10-04', 5, 0, 0)");
    expect(await rows("select id from nap_logs where id in ('f1', 'f2', 'p4-live')")).toHaveLength(3);
  });
});
