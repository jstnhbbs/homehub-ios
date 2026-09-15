import { createHash } from "node:crypto";
import { turso } from "@/db/client";

const PHOTO_MIGRATION = {
  tag: "0017_household_photo",
  createdAt: 1784230000000,
  hash: "119f56f4357b37c3ff6a3e10eb824414e9989942bba40f768626c203ed1492cf",
} as const;

const GROCERIES_MIGRATION = {
  tag: "0018_shopping_to_groceries",
  createdAt: 1784240000000,
  hash: "d38adf4394966dda048e6be7d3a1a5a50e4e0881fbfc2e15b02efb00de2280d8",
} as const;

let pending: Promise<string[]> | null = null;

export function hashMigrationSql(sql: string) {
  return createHash("sha256").update(sql).digest("hex");
}

export async function ensureLatestSchema() {
  pending ??= applyPendingSchema().catch((error) => {
    pending = null;
    throw error;
  });
  return pending;
}

async function applyPendingSchema() {
  const applied: string[] = [];

  if (await tableExists("households") && !(await columnExists("households", "photo"))) {
    await exec("ALTER TABLE `households` ADD `photo` text");
    applied.push("households.photo");
  }
  await recordMigration(PHOTO_MIGRATION);

  if ((await tableExists("shopping_items")) && !(await tableExists("grocery_items"))) {
    await exec("ALTER TABLE `shopping_items` RENAME TO `grocery_items`");
    applied.push("grocery_items.rename");
  }
  if (await tableExists("grocery_items")) {
    await exec("DROP INDEX IF EXISTS `shopping_items_household_idx`");
    await exec("DROP INDEX IF EXISTS `shopping_items_checked_idx`");
    await exec(
      "CREATE INDEX IF NOT EXISTS `grocery_items_household_idx` ON `grocery_items` (`household_id`)",
    );
    await exec(
      "CREATE INDEX IF NOT EXISTS `grocery_items_checked_idx` ON `grocery_items` (`household_id`,`checked`)",
    );
  }
  if (await tableExists("recycle_bin_items")) {
    await exec(
      "UPDATE `recycle_bin_items` SET `item_type` = 'grocery_item' WHERE `item_type` = 'shopping_item'",
    );
  }
  await exec(
    `UPDATE \`users\` SET \`hub_modules\` = REPLACE(\`hub_modules\`, '"shopping"', '"groceries"') WHERE \`hub_modules\` LIKE '%"shopping"%'`,
  );
  await recordMigration(GROCERIES_MIGRATION);

  return applied;
}

async function tableExists(name: string) {
  const result = await turso.execute({
    sql: "select name from sqlite_master where type = 'table' and name = ?",
    args: [name],
  });
  return result.rows.length > 0;
}

async function columnExists(table: string, column: string) {
  const result = await turso.execute(`pragma table_info(${table})`);
  return result.rows.some((row) => row.name === column);
}

async function exec(sql: string) {
  await turso.execute(sql);
}

async function recordMigration(migration: { hash: string; createdAt: number; tag: string }) {
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
