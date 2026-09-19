// Read-only: compares a database's __drizzle_migrations table with drizzle/meta/_journal.json
// and reports what `drizzle-kit migrate` would run. Uses TURSO_DATABASE_URL / TURSO_AUTH_TOKEN.
import { createClient } from "@libsql/client";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const url = process.env.TURSO_DATABASE_URL;
if (!url) throw new Error("TURSO_DATABASE_URL is required");

const turso = createClient({ url, authToken: process.env.TURSO_AUTH_TOKEN });
const journal = JSON.parse(
  readFileSync(path.join(root, "drizzle/meta/_journal.json"), "utf8"),
);
const entries = journal.entries.map((entry) => ({
  tag: entry.tag,
  when: entry.when,
  hash: createHash("sha256")
    .update(readFileSync(path.join(root, "drizzle", `${entry.tag}.sql`)))
    .digest("hex"),
}));

const tables = new Set(
  (await turso.execute("select name from sqlite_master where type = 'table'")).rows.map(
    (row) => String(row.name),
  ),
);
if (!tables.has("__drizzle_migrations")) {
  console.log("No __drizzle_migrations table: `db:migrate` would replay every migration and fail.");
  process.exit(1);
}

const rows = (
  await turso.execute("select hash, created_at from __drizzle_migrations")
).rows.map((row) => ({ hash: String(row.hash), createdAt: Number(row.created_at) }));
const recordedHashes = new Set(rows.map((row) => row.hash));
const recordedTimes = new Set(rows.map((row) => row.createdAt));
const lastCreatedAt = Math.max(0, ...rows.map((row) => row.createdAt));

console.log(`recorded rows: ${rows.length}, journal entries: ${entries.length}`);
console.log("\nJournal entries not recorded in the database (by hash or created_at):");
const unrecorded = entries.filter(
  (entry) => !recordedHashes.has(entry.hash) && !recordedTimes.has(entry.when),
);
console.log(unrecorded.length ? unrecorded.map((entry) => `  ${entry.tag}`).join("\n") : "  none");

// Harmless for drizzle (it only compares created_at), but worth knowing about.
const edited = entries.filter(
  (entry) => !recordedHashes.has(entry.hash) && recordedTimes.has(entry.when),
);
if (edited.length) {
  console.log("\nRecorded by created_at but the SQL file has changed since (hash differs):");
  console.log(edited.map((entry) => `  ${entry.tag}`).join("\n"));
}

// drizzle only compares against the newest recorded created_at, not each row.
const wouldRun = entries.filter((entry) => entry.when > lastCreatedAt);
console.log("\n`db:migrate` would run:");
console.log(wouldRun.length ? wouldRun.map((entry) => `  ${entry.tag}`).join("\n") : "  nothing");

const columns = new Set(
  (await turso.execute("pragma table_info(households)")).rows.map((row) => String(row.name)),
);
console.log("\nSchema state:");
for (const column of ["photo", "calendar_sync_interval_minutes"]) {
  console.log(`  households.${column}: ${columns.has(column) ? "present" : "absent"}`);
}
for (const table of ["grocery_items", "shopping_items", "calendar_connections", "calendars", "calendar_events"]) {
  console.log(`  ${table}: ${tables.has(table) ? "present" : "absent"}`);
}
