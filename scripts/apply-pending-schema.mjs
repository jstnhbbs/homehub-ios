import { createClient } from "@libsql/client";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const PHOTO_MIGRATION = {
  tag: "0017_household_photo",
  createdAt: 1784230000000,
  hash: "119f56f4357b37c3ff6a3e10eb824414e9989942bba40f768626c203ed1492cf",
};

const GROCERIES_MIGRATION = {
  tag: "0018_shopping_to_groceries",
  createdAt: 1784240000000,
  hash: "d38adf4394966dda048e6be7d3a1a5a50e4e0881fbfc2e15b02efb00de2280d8",
};

function hashSql(tag) {
  const sql = readFileSync(path.join(root, "drizzle", `${tag}.sql`));
  return createHash("sha256").update(sql).digest("hex");
}

for (const migration of [PHOTO_MIGRATION, GROCERIES_MIGRATION]) {
  const actual = hashSql(migration.tag);
  if (actual !== migration.hash) {
    throw new Error(`${migration.tag} hash mismatch: ${actual}`);
  }
}

const url = process.env.TURSO_DATABASE_URL;
if (!url) {
  throw new Error("TURSO_DATABASE_URL is required");
}

const turso = createClient({
  url,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

async function tableExists(name) {
  const result = await turso.execute({
    sql: "select name from sqlite_master where type = 'table' and name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function columnExists(table, column) {
  const result = await turso.execute(`pragma table_info(${table})`);
  return result.rows.some((row) => row.name === column);
}

async function recordMigration(migration) {
  if (!(await tableExists("__drizzle_migrations"))) return;
  const existing = await turso.execute({
    sql: "select hash from `__drizzle_migrations` where hash = ? limit 1",
    args: [migration.hash],
  });
  if (existing.rows[0]) return;
  await turso.execute({
    sql: "insert into `__drizzle_migrations` (`hash`, `created_at`) values (?, ?)",
    args: [migration.hash, migration.createdAt],
  });
}

const applied = [];

if ((await tableExists("households")) && !(await columnExists("households", "photo"))) {
  await turso.execute("ALTER TABLE `households` ADD `photo` text");
  applied.push("households.photo");
}
await recordMigration(PHOTO_MIGRATION);

if ((await tableExists("shopping_items")) && !(await tableExists("grocery_items"))) {
  await turso.execute("ALTER TABLE `shopping_items` RENAME TO `grocery_items`");
  applied.push("grocery_items.rename");
}
if (await tableExists("grocery_items")) {
  await turso.execute("DROP INDEX IF EXISTS `shopping_items_household_idx`");
  await turso.execute("DROP INDEX IF EXISTS `shopping_items_checked_idx`");
  await turso.execute(
    "CREATE INDEX IF NOT EXISTS `grocery_items_household_idx` ON `grocery_items` (`household_id`)",
  );
  await turso.execute(
    "CREATE INDEX IF NOT EXISTS `grocery_items_checked_idx` ON `grocery_items` (`household_id`,`checked`)",
  );
}
if (await tableExists("recycle_bin_items")) {
  await turso.execute(
    "UPDATE `recycle_bin_items` SET `item_type` = 'grocery_item' WHERE `item_type` = 'shopping_item'",
  );
}
await turso.execute(
  `UPDATE \`users\` SET \`hub_modules\` = REPLACE(\`hub_modules\`, '"shopping"', '"groceries"') WHERE \`hub_modules\` LIKE '%"shopping"%'`,
);
await recordMigration(GROCERIES_MIGRATION);

const photo = await columnExists("households", "photo");
const grocery = await tableExists("grocery_items");
console.log(JSON.stringify({ ok: true, applied, photo, grocery }));
