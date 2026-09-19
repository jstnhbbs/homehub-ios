import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdNotes } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

const noteUpdateSchema = z.object({
  title: z.string().trim().min(1).max(160).optional(),
  body: z.string().trim().max(2000).optional(),
  pinned: z.boolean().optional(),
});

export async function PATCH(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const household = await requireMobileParentHousehold();
    const { id } = await context.params;
    const input = noteUpdateSchema.parse(await parseJsonBody(request));

    await db
      .update(householdNotes)
      .set({
        ...("title" in input ? { title: input.title } : {}),
        ...("body" in input ? { body: input.body ?? "" } : {}),
        ...("pinned" in input ? { pinned: input.pinned } : {}),
        updatedAt: new Date(),
      })
      .where(
        and(
          eq(householdNotes.id, id),
          eq(householdNotes.householdId, household.id),
        ),
      );

    const updated = await db
      .select()
      .from(householdNotes)
      .where(
        and(
          eq(householdNotes.id, id),
          eq(householdNotes.householdId, household.id),
        ),
      )
      .limit(1);

    if (!updated[0]) throw new Error("Note not found.");
    return mobileJson(updated[0]);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const household = await requireMobileParentHousehold();
    const { id } = await context.params;

    const deleted = await db
      .delete(householdNotes)
      .where(
        and(
          eq(householdNotes.id, id),
          eq(householdNotes.householdId, household.id),
        ),
      )
      .returning({ id: householdNotes.id });

    if (!deleted[0]) throw new Error("Note not found.");
    return Response.json({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
