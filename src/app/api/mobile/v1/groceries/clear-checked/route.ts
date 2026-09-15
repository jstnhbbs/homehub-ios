import { randomUUID } from "node:crypto";
import { addDays } from "date-fns";
import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { groceryItems, recycleBinItems } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function POST() {
  try {
    const household = await requireMobileHousehold();
    const items = await db
      .select()
      .from(groceryItems)
      .where(
        and(eq(groceryItems.householdId, household.id), eq(groceryItems.checked, true)),
      );

    for (const item of items) {
      const deletedAt = new Date();
      await db.insert(recycleBinItems).values({
        id: randomUUID(),
        householdId: household.id,
        itemType: "grocery_item",
        itemId: item.id,
        label: item.title,
        snapshot: JSON.stringify(item),
        deletedAt,
        restoreBy: addDays(deletedAt, 30),
      });
    }

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
