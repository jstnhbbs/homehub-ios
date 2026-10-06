import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { groceryItems } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const input = z
      .object({
        checked: z.boolean(),
      })
      .parse(await parseJsonBody(request));

    const updated = await db
      .update(groceryItems)
      .set({
        checked: input.checked,
        checkedAt: input.checked ? new Date() : null,
        updatedAt: new Date(),
      })
      .where(
        and(eq(groceryItems.id, id), eq(groceryItems.householdId, household.id)),
      )
      .returning();

    if (!updated[0]) throw new Error("Grocery item not found.");
    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const id = z.string().uuid().parse((await context.params).id);
    const item = await db
      .select()
      .from(groceryItems)
      .where(
        and(eq(groceryItems.id, id), eq(groceryItems.householdId, household.id)),
      )
      .limit(1);

    if (!item[0]) throw new Error("Grocery item not found.");

    await db.delete(groceryItems).where(eq(groceryItems.id, id));
    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
