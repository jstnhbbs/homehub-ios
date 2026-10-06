import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { groceryItems } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST() {
  try {
    const household = await requireMobileParentHousehold();
    const items = await db
      .select()
      .from(groceryItems)
      .where(
        and(eq(groceryItems.householdId, household.id), eq(groceryItems.checked, true)),
      );

    await db
      .delete(groceryItems)
      .where(
        and(eq(groceryItems.householdId, household.id), eq(groceryItems.checked, true)),
      );

    return mobileJson({ ok: true, cleared: items.length });
  } catch (error) {
    return handleMobileError(error);
  }
}
