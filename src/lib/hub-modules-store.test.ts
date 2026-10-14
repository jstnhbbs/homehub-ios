import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const dir = mkdtempSync(path.join(tmpdir(), "tugboat-layout-races-"));
process.env.TURSO_DATABASE_URL = `file:${path.join(dir, "test.db")}`;

beforeAll(async () => {
  const { db } = await import("@/db/client");
  const { migrate } = await import("drizzle-orm/libsql/migrator");
  const { users } = await import("@/db/schema");
  await migrate(db, { migrationsFolder: "drizzle" });
  for (const id of ["toggles", "cards", "devices"]) {
    await db.insert(users).values({ id, name: id, email: `${id}@example.com` });
  }
});

afterAll(async () => {
  const { turso } = await import("@/db/client");
  turso.close();
  rmSync(dir, { recursive: true, force: true });
});

describe("layout merge races", () => {
  it("keeps concurrent changes to separate module switches", async () => {
    const { saveUserHubModules, getUserHubModules } = await import("./hub-modules-store");
    await Promise.all([saveUserHubModules("toggles", { notes: false }), saveUserHubModules("toggles", { calendar: false })]);
    expect(await getUserHubModules("toggles")).toMatchObject({ notes: false, calendar: false });
  });

  it("merges individual card changes rather than replacing their whole map", async () => {
    const { saveUserHubModules, getUserHubModules } = await import("./hub-modules-store");
    await Promise.all([saveUserHubModules("cards", { dashboardCards: { notes: false } }),
      saveUserHubModules("cards", { dashboardCards: { snacks: false } })]);
    expect((await getUserHubModules("cards")).dashboardCards).toMatchObject({ notes: false, snacks: false, chores: true });
  });

  it("keeps phone and tablet size edits from separate devices", async () => {
    const { saveUserHubModules, getUserHubModules } = await import("./hub-modules-store");
    await Promise.all([saveUserHubModules("devices", { dashboardCardSizesPhone: { snacks: "large" } }),
      saveUserHubModules("devices", { dashboardCardSizesTablet: { notes: "large" } })]);
    expect(await getUserHubModules("devices")).toMatchObject({
      dashboardCardSizesPhone: { snacks: "large" }, dashboardCardSizesTablet: { notes: "large" },
    });
  });
});
