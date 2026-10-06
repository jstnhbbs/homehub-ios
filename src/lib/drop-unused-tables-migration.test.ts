import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { createClient, type Client } from "@libsql/client";
import { drizzle } from "drizzle-orm/libsql";
import { migrate } from "drizzle-orm/libsql/migrator";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

// Migration 0028 drops five tables nothing reads or writes any more (school_*, notification_preferences,
// recycle_bin_items). This builds the database as it stood before it, with rows in every one of them and
// in the tables that must be left alone, then applies 0028 the way a deploy does.

const TAG = "0028_drop_unused_tables";
const dropped = [
  "school_schedule_entries",
  "school_subjects",
  "school_periods",
  "notification_preferences",
  "recycle_bin_items",
];

const dir = mkdtempSync(path.join(tmpdir(), "beacon-drop-tables-"));
const folder = path.join(dir, "drizzle");
let client: Client;

async function rows(sql: string) {
  return (await client.execute(sql)).rows.map((row) => ({ ...row }));
}

async function tableNames() {
  return (await rows("select name from sqlite_master where type = 'table'")).map((row) => String(row.name));
}

beforeAll(async () => {
  cpSync(path.resolve("drizzle"), folder, { recursive: true });
  const journalPath = path.join(folder, "meta/_journal.json");
  const journal = JSON.parse(readFileSync(journalPath, "utf8")) as { entries: Array<{ tag: string }> };
  const at = journal.entries.findIndex((entry) => entry.tag === TAG);
  expect(at, "the migration should be in the journal").toBeGreaterThan(0);

  // The database as it stood before 0028.
  writeFileSync(journalPath, JSON.stringify({ ...journal, entries: journal.entries.slice(0, at) }));
  client = createClient({ url: `file:${path.join(dir, "test.db")}` });
  await migrate(drizzle(client), { migrationsFolder: folder });

  await client.execute("insert into households (id, name, invite_code, guest_invite_code, created_at, updated_at) values ('h', 'H', 'A', 'B', 0, 0)");
  await client.execute("insert into users (id, name, email, email_verified, created_at, updated_at) values ('u', 'U', 'u@example.com', 0, 0, 0)");
  await client.execute("insert into profiles (id, household_id, profile_type, name, color, sort_order, created_at, updated_at) values ('p', 'h', 'child', 'P', '#fff', 0, 0, 0)");
  await client.execute("insert into grocery_items (id, household_id, title, checked, created_at, updated_at) values ('g', 'h', 'Milk', 0, 0, 0)");

  // Rows in everything that is about to go, including the ones that point at each other.
  await client.execute("insert into school_subjects (id, household_id, name, created_at, updated_at) values ('s', 'h', 'Math', 0, 0)");
  await client.execute("insert into school_periods (id, household_id, label, created_at, updated_at) values ('per', 'h', 'First', 0, 0)");
  await client.execute("insert into school_schedule_entries (id, household_id, profile_id, subject_id, period_id, weekday, created_at, updated_at) values ('e', 'h', 'p', 's', 'per', 1, 0, 0)");
  await client.execute("insert into notification_preferences (id, household_id, user_id, created_at, updated_at) values ('n', 'h', 'u', 0, 0)");
  await client.execute("insert into recycle_bin_items (id, household_id, item_type, item_id, label, snapshot, deleted_at) values ('r', 'h', 'grocery_item', 'x', 'Old', '{}', 0)");

  // Now apply 0028 (and anything after it), as a deploy would.
  cpSync(path.resolve("drizzle/meta/_journal.json"), journalPath);
  await migrate(drizzle(client), { migrationsFolder: folder });
});

afterAll(() => {
  client.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("migration 0028", () => {
  it("drops the five unused tables, even with rows in them that reference each other", async () => {
    const names = await tableNames();
    for (const table of dropped) expect(names, table).not.toContain(table);
  });

  it("leaves no orphaned indexes behind", async () => {
    const left = await rows("select name from sqlite_master where type = 'index' and (name like 'school_%' or name like 'notification_preferences_%' or name like 'recycle_bin_%')");
    expect(left).toEqual([]);
  });

  it("leaves the data that is in use alone", async () => {
    expect(await rows("select id from households")).toEqual([{ id: "h" }]);
    expect(await rows("select id from users")).toEqual([{ id: "u" }]);
    expect(await rows("select id from profiles")).toEqual([{ id: "p" }]);
    expect(await rows("select title from grocery_items")).toEqual([{ title: "Milk" }]);
  });

  it("keeps the sign-in service's own tables, which a lookup of 'unused' could mistake for dead", async () => {
    const names = await tableNames();
    for (const table of ["users", "sessions", "accounts", "verifications", "rate_limits"]) {
      expect(names, table).toContain(table);
    }
  });

  it("does not stop a household from being deleted", async () => {
    await client.execute("delete from households where id = 'h'");
    expect(await rows("select id from grocery_items")).toEqual([]);
    expect(await rows("select id from profiles")).toEqual([]);
  });
});
