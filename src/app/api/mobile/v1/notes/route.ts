import { randomUUID } from "node:crypto";
import { desc, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdNotes } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

const noteInputSchema = z.object({
  title: z.string().trim().min(1).max(160),
  body: z.string().trim().max(2000).optional(),
  pinned: z.boolean().optional(),
});

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const notes = await db
      .select()
      .from(householdNotes)
      .where(eq(householdNotes.householdId, household.id))
      .orderBy(desc(householdNotes.pinned), desc(householdNotes.updatedAt));

    return mobileJson(notes);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function POST(request: Request) {
  try {
    const user = await requireMobileUser();
    // Any member, including guests, can add a note; only parents edit or delete.
    const household = await requireMobileHousehold();
    const input = noteInputSchema.parse(await parseJsonBody(request));
    const id = randomUUID();

    await db.insert(householdNotes).values({
      id,
      householdId: household.id,
      createdByUserId: user.id,
      title: input.title,
      body: input.body ?? "",
      color: "#f8e8bf",
      pinned: input.pinned ?? false,
    });

    const created = await db
      .select()
      .from(householdNotes)
      .where(eq(householdNotes.id, id))
      .limit(1);

    return mobileJson(created[0], 201);
  } catch (error) {
    return handleMobileError(error);
  }
}
