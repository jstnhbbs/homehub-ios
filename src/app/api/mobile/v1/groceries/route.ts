import { randomUUID } from "node:crypto";
import { asc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { groceryItems } from "@/db/schema";
import { categorizeGroceryItem, parseGroceryTitle } from "@/lib/groceries";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const shortText = z.string().trim().min(1).max(120);

const groceryInputSchema = z.object({
  title: shortText,
  category: z.string().trim().max(120).optional(),
});

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const items = await db
      .select()
      .from(groceryItems)
      .where(eq(groceryItems.householdId, household.id))
      .orderBy(
        asc(groceryItems.checked),
        asc(groceryItems.category),
        asc(groceryItems.createdAt),
      );

    return mobileJson(items);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = groceryInputSchema.parse(await parseJsonBody(request));
    const parsed = parseGroceryTitle(input.title);
    const category = input.category || categorizeGroceryItem(parsed.title);
    const id = randomUUID();

    await db.insert(groceryItems).values({
      id,
      householdId: household.id,
      title: parsed.title,
      quantity: parsed.quantity || null,
      category,
    });

    const created = await db
      .select()
      .from(groceryItems)
      .where(eq(groceryItems.id, id))
      .limit(1);

    return mobileJson(created[0], 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
