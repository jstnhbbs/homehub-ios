import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { householdMembers } from "@/db/schema";
import { updateHouseholdMemberRole } from "@/lib/household-members";
import { householdRoles, isGuest } from "@/lib/household-roles";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
  requireMobileUser,
} from "@/lib/mobile/http";

type RouteContext = { params: Promise<{ userId: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  try {
    const user = await requireMobileUser();
    const household = await requireMobileParentHousehold();
    const userId = z.string().parse((await context.params).userId);
    const input = z
      .object({
        role: z.enum(householdRoles),
      })
      .parse(await parseJsonBody(request));

    const role = await updateHouseholdMemberRole({
      householdId: household.id,
      actorUserId: user.id,
      actorRole: household.role,
      targetUserId: userId,
      nextRole: input.role,
    });

    return mobileJson({ ok: true, role });
  } catch (error) {
    return handleMobileError(error);
  }
}

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
