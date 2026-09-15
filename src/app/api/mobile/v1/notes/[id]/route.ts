import { and, eq } from "drizzle-orm";
import { db } from "@/db/client";
import { householdNotes } from "@/db/schema";
import {
  handleMobileError,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function DELETE(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  try {
    const household = await requireMobileHousehold();
    const { id } = await context.params;

    await db
      .delete(householdNotes)
      .where(
        and(
          eq(householdNotes.id, id),
          eq(householdNotes.householdId, household.id),
        ),
      );

    return Response.json({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
