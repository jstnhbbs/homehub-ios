import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { users } from "@/db/schema";
import {
  type HubModules,
  type HubModulesInput,
  mergeHubModules,
  parseHubModules,
  serializeHubModules,
} from "@/lib/hub-modules";

export async function getUserHubModules(userId: string): Promise<HubModules> {
  const [row] = await db
    .select({ hubModules: users.hubModules })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);

  return parseHubModules(row?.hubModules);
}

export async function saveUserHubModules(
  userId: string,
  modules: HubModulesInput,
): Promise<HubModules> {
  // Compare-and-swap keeps edits from different devices without holding a transaction across network reads.
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const [row] = await db
      .select({ hubModules: users.hubModules })
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    if (!row) throw new Error("Account not found.");
    const current = parseHubModules(row.hubModules);
    const next = mergeHubModules({
      ...current,
      ...modules,
      dashboardCards: { ...current.dashboardCards, ...modules.dashboardCards },
      dashboardCardSizesPhone: {
        ...current.dashboardCardSizesPhone,
        ...modules.dashboardCardSizesPhone,
      },
      dashboardCardSizesTablet: {
        ...current.dashboardCardSizesTablet,
        ...modules.dashboardCardSizesTablet,
      },
    });
    const updated = await db
      .update(users)
      .set({ hubModules: serializeHubModules(next), updatedAt: new Date() })
      .where(and(eq(users.id, userId), eq(users.hubModules, row.hubModules)))
      .returning({ id: users.id });
    if (updated.length) return next;
  }
  throw new Error("Your layout changed on another device. Please try again.");
}
