import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdMembers } from "@/db/schema";
import { isGuest } from "@/lib/household-roles";
import {
  handleMobileError,
  mobileJson,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ userId: string }> };

export async function DELETE(_request: Request, context: RouteContext) {
  try {
    const household = await requireMobileParentHousehold();
    const userId = z.string().parse((await context.params).userId);

    const member = await db
      .select({ role: householdMembers.role })
      .from(householdMembers)
      .where(
        and(
          eq(householdMembers.householdId, household.id),
          eq(householdMembers.userId, userId),
        ),
      )
      .limit(1);

    if (!member[0] || !isGuest(member[0].role)) {
      throw new Error("Only guest members can be removed here.");
    }

    await db
      .delete(householdMembers)
      .where(
        and(
          eq(householdMembers.householdId, household.id),
          eq(householdMembers.userId, userId),
        ),
      );

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
