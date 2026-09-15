import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { hashMigrationSql } from "./ensure-schema";

const drizzleDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../drizzle",
);

describe("ensureLatestSchema migration hashes", () => {
  it("matches 0017 household photo SQL", () => {
    const sql = readFileSync(
      path.join(drizzleDir, "0017_household_photo.sql"),
      "utf8",
    );
    expect(hashMigrationSql(sql)).toBe(
      "119f56f4357b37c3ff6a3e10eb824414e9989942bba40f768626c203ed1492cf",
    );
  });

  it("matches 0018 shopping to groceries SQL", () => {
    const sql = readFileSync(
      path.join(drizzleDir, "0018_shopping_to_groceries.sql"),
      "utf8",
    );
    expect(hashMigrationSql(sql)).toBe(
      "d38adf4394966dda048e6be7d3a1a5a50e4e0881fbfc2e15b02efb00de2280d8",
    );
  });
});
