import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { users } from "@/db/schema";
import {
  type HubModules,
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
  modules: Partial<HubModules>,
): Promise<HubModules> {
  const current = await getUserHubModules(userId);
  const next = mergeHubModules({ ...current, ...modules });

  await db
    .update(users)
    .set({
      hubModules: serializeHubModules(next),
      updatedAt: new Date(),
    })
    .where(eq(users.id, userId));

  return next;
}
